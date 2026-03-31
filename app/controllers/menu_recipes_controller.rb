# Gestion des repas d'un menu (MenuRecipe)
# Toutes les actions sont nestées sous /menus/:menu_id/menu_recipes.
# Réponses Turbo Stream pour une expérience fluide sans rechargement de page.
class MenuRecipesController < ApplicationController
  include TurboFlashable

  before_action :authenticate_user!
  before_action :set_menu
  before_action :set_menu_recipe, only: [ :update, :destroy ]
  before_action :authorize_menu_recipe, only: [ :update, :destroy ]
  before_action :authorize_reorder, only: [ :reorder ]

  # POST /menus/:menu_id/menu_recipes
  # Ajout manuel d'une recette au menu (via fiche recette → "Ajouter à mon menu")
  def create
    @menu_recipe = @menu.menu_recipes.new(menu_recipe_create_params)
    @menu_recipe.position = next_position
    authorize @menu_recipe

    if @menu_recipe.save
      respond_success(redirect_path: @menu)
    else
      respond_error(@menu_recipe, redirect_path: @menu)
    end
  end

  # PATCH /menus/:menu_id/menu_recipes/:id
  # Mise à jour du nombre de personnes pour ce repas
  def update
    if @menu_recipe.update(menu_recipe_update_params)
      respond_success(redirect_path: @menu)
    else
      respond_error(@menu_recipe, redirect_path: @menu)
    end
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

  # DELETE /menus/:menu_id/menu_recipes/:id
  # Suppression d'un repas du menu brouillon
  def destroy
    @menu_recipe.destroy
    respond_success(redirect_path: @menu)
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

  # Paramètres pour la création (recette + nombre de personnes)
  def menu_recipe_create_params
    params.require(:menu_recipe).permit(:recipe_id, :number_of_people)
  end

  # Seul le nombre de personnes est modifiable après création
  def menu_recipe_update_params
    params.require(:menu_recipe).permit(:number_of_people)
  end

  # Calcule la prochaine position disponible pour ce menu
  def next_position
    @menu.menu_recipes.maximum(:position).to_i + 1
  end
end
