# Gestion des menus (UC1 - Génération, UC2 - Personnalisation, UC3 - Liste de courses)
# Un menu est toujours persisté en base, même à l'état brouillon (status: :draft).
# La transition draft → active déclenche la génération de la liste de courses.
#
# Actions extraites dans des concerns pour limiter la complexité :
# - Menus::Customizable   → replace_meal, regenerate                   (UC2)
# - Menus::GroceryManageable → grocery                                 (UC3)
class MenusController < ApplicationController
  include TurboFlashable
  include Menus::Customizable
  include Menus::GroceryManageable

  MEMBER_ACTIONS = %i[show edit update destroy activate reactivate revert_to_draft replace_meal
                      grocery regenerate_grocery regenerate adjust_meal_count].freeze

  # Une commande sans le moindre repas n'a rien à composer (UC7, chapitre 2).
  # Message partagé avec la re-génération (voir Menus::Customizable#regenerate).
  NO_MEALS_ALERT = "Choisis au moins un repas pour composer ton menu.".freeze

  # Bouton direct « Créer un menu » d'une utilisatrice qui n'a pas encore décrit
  # sa semaine type : on l'invite à la décrire au lieu de lui opposer une erreur.
  DESCRIBE_WEEK_NOTICE = "Décris ta semaine type pour générer ton menu.".freeze

  before_action :authenticate_user!
  before_action :set_menu, only: MEMBER_ACTIONS
  before_action :authorize_menu, only: MEMBER_ACTIONS

  # GET /menus
  def index
    authorize Menu
    @menus = policy_scope(Menu).recent.includes(menu_recipes: { recipe: :photo_attachment })
    classify_menus
  end

  # GET /menus/:id
  def show
    # Les ingrédients (et leur table pivot preparations) ne servent qu'au badge
    # « De saison » de la vue archivée (Recipe#seasonal_for_month?). On ne les
    # charge donc que dans ce cas, pour éviter un eager loading inutile
    # (signalé par Bullet) sur les menus brouillon et actif.
    @menu_recipes = if @menu.status_archived?
      @menu.menu_recipes.includes(recipe: [ :photo_attachment, :ingredients ]).by_position
    else
      @menu.meals_for_display
    end
  end

  # GET /menus/new
  def new
    prepare_new_form
    authorize @menu
  end

  # POST /menus
  # UC1 : Génère un menu brouillon et le persiste immédiatement.
  # Deux cas selon l'origine de l'appel :
  #   - Formulaire soumis (params[:menu] présent) : onboarding ou personnalisation ponctuelle.
  #   - POST direct depuis l'index (pas de params menu) : utilisateur configuré, utilise ses préférences.
  # Des pools trop maigres ne font jamais échouer la génération (UC7) : le
  # brouillon expose les manques à combler depuis le catalogue.
  def create
    authorize Menu
    return handle_empty_meal_counts unless requested_meal_counts.any?

    save_user_defaults! if form_params_present? && params.dig(:menu, :save_as_defaults) == "1"
    replacing_draft = current_user.menus.status_draft.exists?
    @menu = Menus::GenerateService.call(**generation_params)
    redirect_to @menu, notice: create_notice(replacing_draft), status: :see_other
  end

  # GET /menus/:id/edit
  def edit; end

  # PATCH /menus/:id
  # Répond en Turbo Stream pour les mises à jour inline (nom, personnes) depuis le brouillon.
  # Propage default_people à tous les repas si cette valeur a changé.
  def update
    new_people = menu_update_params[:default_people]
    @people_changed = new_people.present? && @menu.default_people.to_i != new_people.to_i

    if @menu.update(menu_update_params)
      @menu.menu_recipes.update_all(number_of_people: @menu.default_people) if @people_changed
      @menu_recipes = @menu.meals_for_display

      respond_to do |format|
        format.turbo_stream
        format.html { redirect_to @menu, notice: "Menu mis à jour.", status: :see_other }
      end
    else
      @menu_recipes = @menu.meals_for_display
      respond_to do |format|
        format.turbo_stream { render_flash_stream(alert: @menu.errors.full_messages.first) }
        format.html { render :edit, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /menus/:id
  def destroy
    @menu.destroy
    redirect_to menus_path, notice: "Menu supprimé.", status: :see_other
  end

  # POST /menus/:id/activate
  # UC1 : Valide le menu brouillon et génère la liste de courses
  # Archive automatiquement l'éventuel menu actif précédent
  # Redirige directement vers la liste de courses : c'est la seule chose que
  # cette action produit, inutile de faire passer par la vue du menu.
  def activate
    transition_menu(:activate!, "Menu activé ! Votre liste de courses est prête.",
                                "Impossible d'activer le menu",
                                success_redirect: grocery_menu_path(@menu))
  end

  # POST /menus/:id/reactivate
  # Réactive un menu archivé : l'ancien menu actif est archivé,
  # celui-ci redevient actif et sa liste de courses est régénérée.
  def reactivate
    transition_menu(:reactivate!, "Menu réactivé ! Votre liste de courses a été mise à jour.",
                                  "Impossible de réactiver le menu",
                                  success_redirect: grocery_menu_path(@menu))
  end

  # POST /menus/:id/revert_to_draft
  # R3.2bis : Repasse un menu actif en brouillon pour le rendre modifiable.
  # La liste de courses est conservée et sera réconciliée à la revalidation.
  def revert_to_draft
    transition_menu(:revert_to_draft!, "Menu repassé en brouillon. Modifie-le puis revalide.",
                                       "Impossible de repasser le menu en brouillon")
  end

  private

  def set_menu
    @menu = Menu.find(params[:id])
  end

  def authorize_menu
    authorize @menu
  end

  # Répartit les menus chargés en catégories pour la vue index.
  # Un seul brouillon peut exister par utilisateur : l'array garde la vue simple
  # et évite une branche spéciale dans les partials existants.
  def classify_menus
    @drafts   = @menus.select(&:status_draft?)
    @active   = @menus.find(&:status_active?)
    @archived = @menus.select(&:status_archived?)
  end

  # Paramètres utilisés par Menus::GenerateService
  # Deux sources possibles : formulaire soumis (onboarding / personnalisation) ou préférences utilisateur.
  def generation_params
    # Ce qui ne dépend pas de la porte d'entrée : requested_meal_counts sait
    # déjà d'où vient la répartition.
    common = { user: current_user, meal_counts: requested_meal_counts }

    if form_params_present?
      common.merge(diet:           menu_params[:diet],
                   default_people: menu_params[:default_people].to_i,
                   name:           menu_params[:name].presence)
    else
      common.merge(diet:           current_user.default_diet,
                   default_people: current_user.default_people,
                   name:           nil)
    end
  end

  # Vrai si le formulaire de génération a été soumis (onboarding / personnalisation ponctuelle).
  # Faux si le POST vient du bouton direct "Créer un menu" pour les utilisateurs configurés.
  def form_params_present?
    params[:menu].present?
  end

  # Mémorise les paramètres du formulaire comme préférences par défaut de l'utilisateur.
  def save_user_defaults!
    current_user.update(
      default_diet:           menu_params[:diet],
      default_people:         menu_params[:default_people].to_i,
      default_meal_counts:    requested_meal_counts.to_h,
      preferences_configured: true
    )
  end

  # Répartition des repas commandée à la génération : le formulaire de
  # paramètres l'envoie dans menu[meal_counts] ; le bouton direct « Créer un
  # menu » rejoue la semaine type mémorisée. Les params ne sont volontairement
  # pas « permit »és : MealCounts ne retient que les moments connus, ce qui
  # vaut liste blanche.
  def requested_meal_counts
    @requested_meal_counts ||= if form_params_present?
      MealCounts.from_hash(params.dig(:menu, :meal_counts))
    else
      current_user.preferred_meal_counts
    end
  end

  # Aucun repas commandé : deux situations, deux réponses.
  def handle_empty_meal_counts
    if form_params_present?
      # Garde-fou serveur — côté client, le bouton est déjà désactivé.
      render_new_with_alert(NO_MEALS_ALERT)
    else
      redirect_to new_menu_path, notice: DESCRIBE_WEEK_NOTICE, status: :see_other
    end
  end

  # Variables du formulaire de génération, partagées par l'affichage initial et
  # par ses ré-affichages en erreur.
  def prepare_new_form
    @menu = Menu.new(diet: current_user.default_diet, default_people: current_user.default_people)
    @existing_draft = current_user.menus.status_draft.recent.first
  end

  # Ré-affiche le formulaire de génération avec un message d'alerte.
  def render_new_with_alert(message)
    flash.now[:alert] = message
    prepare_new_form
    render :new, status: :unprocessable_entity
  end

  # Message flash après génération, adapté selon le parcours.
  def create_notice(replacing_draft)
    if replacing_draft
      "Nouveau menu généré. L'ancien menu à valider a été remplacé."
    elsif form_params_present?
      "Menu généré ! Personnalisez-le avant de valider."
    else
      "Menu généré avec vos paramètres habituels. Personnalisez-le si besoin."
    end
  end

  # Transition d'état du menu (activate/reactivate/revert_to_draft) avec gestion
  # d'erreur unifiée. En cas d'échec on retombe toujours sur la vue du menu :
  # success_redirect ne s'applique qu'à la transition réussie.
  #
  # Seules les erreurs MÉTIER attendues deviennent un message flash : une garde
  # d'état refusée et un enregistrement invalide (validations du menu ou d'un
  # article de courses). Tout le reste — NoMethodError et consorts — est un bug
  # de programmation : il doit remonter en 500 pour être vu et corrigé, plutôt
  # que de se déguiser en message poli à l'utilisatrice.
  def transition_menu(method, success_notice, failure_prefix, success_redirect: @menu)
    @menu.public_send(method)
    redirect_to success_redirect, notice: success_notice, status: :see_other
  rescue Menu::InvalidTransitionError, ActiveRecord::RecordInvalid => error
    redirect_to @menu, alert: "#{failure_prefix} : #{error.message}", status: :see_other
  end

  # Paramètres pour la génération et re-génération d'un menu.
  # La répartition des repas n'y figure pas : elle passe par requested_meal_counts,
  # qui la normalise (voir MealCounts).
  def menu_params
    params.require(:menu).permit(:name, :diet, :default_people)
  end

  # Paramètres pour la mise à jour d'un menu (nom, personnes par défaut)
  def menu_update_params
    params.require(:menu).permit(:name, :default_people)
  end
end
