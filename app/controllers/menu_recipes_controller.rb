# Gestion des repas d'un menu (MenuRecipe)
# Toutes les actions sont nestées sous /menus/:menu_id/menu_recipes.
# Réponses Turbo Stream pour une expérience fluide sans rechargement de page.
class MenuRecipesController < ApplicationController
  before_action :authenticate_user!
  before_action :set_menu
  before_action :set_menu_recipe, only: [ :update, :destroy ]
  before_action :authorize_menu_recipe, only: [ :update, :destroy ]

  # POST /menus/:menu_id/menu_recipes
  # Ajout manuel d'une recette au menu (via fiche recette → "Ajouter à mon menu")
  def create
    @menu_recipe = @menu.menu_recipes.new(menu_recipe_create_params)
    authorize @menu_recipe

    if @menu_recipe.save
      respond_to do |format|
        format.turbo_stream
        format.html { redirect_to @menu }
      end
    else
      respond_to do |format|
        format.turbo_stream { render_flash_stream(alert: @menu_recipe.errors.full_messages.to_sentence) }
        format.html { redirect_to @menu, alert: @menu_recipe.errors.full_messages.to_sentence }
      end
    end
  end

  # PATCH /menus/:menu_id/menu_recipes/:id
  # Mise à jour du nombre de personnes pour ce repas
  def update
    if @menu_recipe.update(menu_recipe_update_params)
      respond_to do |format|
        format.turbo_stream
        format.html { redirect_to @menu }
      end
    else
      respond_to do |format|
        format.turbo_stream { render_flash_stream(alert: @menu_recipe.errors.full_messages.to_sentence) }
        format.html { redirect_to @menu, alert: @menu_recipe.errors.full_messages.to_sentence }
      end
    end
  end

  # DELETE /menus/:menu_id/menu_recipes/:id
  # Suppression d'un repas du menu brouillon
  def destroy
    @menu_recipe.destroy
    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to @menu }
    end
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

  def render_flash_stream(alert:)
    render turbo_stream: turbo_stream.replace(
      "flash",
      partial: "shared/flash",
      locals: { flash: { alert: alert } }
    )
  end

  # Paramètres pour la création (recette + nombre de personnes)
  def menu_recipe_create_params
    params.require(:menu_recipe).permit(:recipe_id, :number_of_people)
  end

  # Seul le nombre de personnes est modifiable après création
  def menu_recipe_update_params
    params.require(:menu_recipe).permit(:number_of_people)
  end
end
