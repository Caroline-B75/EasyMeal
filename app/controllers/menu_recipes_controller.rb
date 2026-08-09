# Gestion des repas d'un menu (MenuRecipe)
# Toutes les actions sont nestées sous /menus/:menu_id/menu_recipes.
# Réponses Turbo Stream pour une expérience fluide sans rechargement de page.
# L'ajout d'un repas passe par le catalogue (Recipes::DraftManageable) : ici ne
# restent que la vie d'un repas déjà en place — personnes, moment, jour, ordre, retrait.
class MenuRecipesController < ApplicationController
  include TurboFlashable

  # Actions qui portent sur un @menu_recipe déjà existant (chargé + autorisé
  # en amont). reorder s'en distingue : il opère sur le menu entier (voir
  # authorize_reorder) et ne cible aucun MenuRecipe précis.
  MUTATE_ACTIONS = %i[update destroy move_up move_down].freeze

  before_action :authenticate_user!
  before_action :set_menu
  before_action :set_menu_recipe, only: MUTATE_ACTIONS
  before_action :authorize_menu_recipe, only: MUTATE_ACTIONS
  before_action :authorize_reorder, only: [ :reorder ]

  # PATCH /menus/:menu_id/menu_recipes/:id
  # Mise à jour d'un repas : personnes, moment ou jour. La réponse est taillée
  # sur ce qui a réellement changé, et jamais plus large : chaque champ est
  # piloté par un <select> qui vit DANS la carte, et re-rendre la carte détruit
  # le <select> que l'utilisatrice vient d'actionner — il perd le focus et la
  # page saute.
  #   - moment    : la carte reste où elle est (grille unique), seul le décompte
  #                 des manques change → on ne remplace que son alerte ;
  #   - jour      : la teinte de la carte est posée dans la foulée côté client
  #                 (menu-customize#setDay) → rien à re-rendre ;
  #   - personnes : le <select> affiche déjà le choix → rien à re-rendre.
  def update
    return respond_error(@menu_recipe, redirect_path: @menu) unless @menu_recipe.update(menu_recipe_update_params)
    return respond_no_content unless @menu_recipe.saved_change_to_meal_type?

    @menu_recipes = @menu.meals_for_display
    respond_success(redirect_path: @menu)
  end

  # PATCH /menus/:menu_id/menu_recipes/reorder
  # UC2 : Persiste l'ordre des repas après réordonnement drag & drop
  def reorder
    ids = Array(params[:ids]).map(&:to_i)
    ids.each_with_index do |id, index|
      @menu.menu_recipes.where(id: id).update_all(position: index)
    end
    head :ok
  end

  # PATCH /menus/:menu_id/menu_recipes/:id/move_up
  # PATCH /menus/:menu_id/menu_recipes/:id/move_down
  # UC7 : réordonnancement mobile — le drag & drop HTML5 ne fonctionne pas au
  # tactile. Échange la position avec le repas voisin dans le sens demandé ;
  # aucun effet aux extrémités (le bouton y est aussi désactivé côté vue).
  # Disponible sur le brouillon ET le menu actif : l'ordre de la grille reste
  # à l'utilisatrice après validation.
  def move_up
    swap_with_neighbor(-1)
  end

  def move_down
    swap_with_neighbor(1)
  end

  # DELETE /menus/:menu_id/menu_recipes/:id
  # Suppression d'un repas du menu brouillon. La réponse Turbo Stream re-rend
  # le bloc des repas et les réglages (UC7) : compte, manques, répartition et
  # bouton de validation retombent juste.
  def destroy
    @menu_recipe.destroy
    refresh_meals
  end

  private

  # Charge et autorise l'accès au menu parent (lecture suffit pour accéder aux enfants)
  def set_menu
    @menu = Menu.find(params[:menu_id])
    authorize @menu, :show?
  end

  def set_menu_recipe
    @menu_recipe = @menu.menu_recipes.find(params[:id])
  end

  def authorize_menu_recipe
    authorize @menu_recipe
  end

  # Seul le propriétaire du menu peut réordonner ses repas
  def authorize_reorder
    authorize @menu, :update?
  end

  # Échange la position de @menu_recipe avec son voisin immédiat dans le sens
  # demandé — l'ordre de la grille appartient à l'utilisatrice, il ne connaît
  # aucune frontière de moment. target_index hors bornes ⇒ pas de voisin :
  # meals[-1] renverrait le dernier élément (indexation négative Ruby) au lieu
  # de nil, d'où la vérification explicite avec between?.
  def swap_with_neighbor(offset)
    meals = @menu.meals_for_display.to_a
    target_index = meals.index(@menu_recipe) + offset
    neighbor = meals[target_index] if target_index.between?(0, meals.size - 1)

    if neighbor
      @menu_recipe.position, neighbor.position = neighbor.position, @menu_recipe.position
      MenuRecipe.transaction do
        @menu_recipe.save!
        neighbor.save!
      end
    end

    refresh_meals
  end

  # Réponse Turbo Stream partagée par destroy / move_up / move_down : re-rend
  # d'un seul tenant le bloc des repas du menu — celui du brouillon (avec le
  # panneau de réglages, voir menus/refresh_draft.turbo_stream.haml, partagé
  # avec l'ajustement des quotas) ou celui du menu actif (menus/refresh_active,
  # ⬆️/⬇️ après validation). La collection est (re)chargée ici et non réutilisée
  # d'un appelant : après un échange de positions, seule une requête fraîche
  # donne le nouvel ordre.
  def refresh_meals
    @menu_recipes = @menu.meals_for_display
    respond_to do |format|
      format.turbo_stream { render @menu.status_draft? ? "menus/refresh_draft" : "menus/refresh_active" }
      format.html { redirect_to @menu }
    end
  end

  # Changement de personnes ou de jour (ou re-sélection de la valeur courante) :
  # l'écran est déjà à jour sans le serveur — le <select> affiche le choix et la
  # teinte de jour est posée par menu-customize#setDay. Turbo accepte un 204 et
  # laisse la page exactement en l'état — la meilleure réponse possible quand il
  # n'y a rien à redessiner.
  def respond_no_content
    respond_to do |format|
      format.turbo_stream { head :no_content }
      format.html { redirect_to @menu }
    end
  end

  # Brouillon : personnes, moment et jour restent ouverts. Menu validé : seul
  # le jour — pure annotation visuelle, sans effet sur la liste de courses —
  # est encore modifiable ; personnes et moment engagent ce qui a été validé.
  # La carte ne propose plus ces contrôles, on les refuse aussi ici.
  def menu_recipe_update_params
    permitted = @menu.status_draft? ? %i[number_of_people meal_type day_of_week] : %i[day_of_week]
    params.require(:menu_recipe).permit(*permitted)
  end
end
