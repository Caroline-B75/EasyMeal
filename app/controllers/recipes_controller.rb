# Gestion des recettes (CRUD)
# Index & show : accessibles à tous (UC4, UC5)
# Create/Update/Destroy : réservés aux admins (gestion du catalogue)
class RecipesController < ApplicationController
  before_action :authenticate_user!, except: [ :index, :show ]
  before_action :set_recipe, only: [ :show, :edit, :update, :destroy, :toggle_favorite, :add_to_menu ]
  before_action :authorize_recipe, only: [ :show, :edit, :update, :destroy ]

  # GET /recipes
  # UC5 : Catalogue & Recherche de recettes avec filtres
  def index
    authorize Recipe
    base_scope = recipes_base_scope
    recipes = Recipes::FilterService.call(base_scope, params)
                .includes(:tags, :ingredients, photo_attachment: :blob)
                .order(params[:sort] || :name)
    @pagy, @recipes = pagy(recipes, items: 20)
    @tags = Tag.joins(:recipes).distinct.alphabetical
  end

  # GET /recipes/:id
  # UC4 : Fiche recette avec ingrédients, étapes, interactions (favoris, notes)
  def show
    @servings = (params[:servings] || recipe.default_servings).to_i
    @preparations_by_category = recipe.preparations.includes(:ingredient)
                                      .group_by { |p| p.ingredient.category }
    load_user_recipe_data if current_user
    @pagy_reviews, @reviews = pagy(recipe.reviews.recent.includes(:user), items: 10)
  end

  # GET /recipes/new
  # Formulaire de création (admin only)
  def new
    @recipe = Recipe.new
    authorize @recipe
    @recipe.preparations.build
  end

  # GET /recipes/:id/edit
  # Formulaire d'édition (admin only)
  def edit
    recipe.ensure_preparation_form_ready
  end

  # POST /recipes
  # Création d'une recette (admin only)
  def create
    @recipe = Recipe.new(recipe_params)
    authorize @recipe

    if @recipe.save
      redirect_to @recipe, notice: "Recette créée avec succès."
    else
      render :new, status: :unprocessable_entity
    end
  end

  # PATCH/PUT /recipes/:id
  # Mise à jour d'une recette (admin only)
  def update
    if recipe.update(recipe_params)
      redirect_to recipe, notice: "Recette mise à jour avec succès."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  # DELETE /recipes/:id
  # Suppression d'une recette (admin only)
  def destroy
    recipe.destroy
    redirect_to recipes_path, notice: "Recette supprimée avec succès."
  end

  # POST /recipes/:id/toggle_favorite
  # UC4 : Toggle favori (ajoute si absent, supprime si présent)
  def toggle_favorite
    added = FavoriteRecipe.toggle_for(user: current_user, recipe: recipe)
    respond_to do |format|
      format.html { redirect_with_favorite_notice(added) }
      format.turbo_stream { render_favorite_turbo_stream(added) }
    end
  end

  # POST /recipes/:id/add_to_menu
  # UC2 : Ajoute la recette au menu brouillon en cours de l'utilisateur
  def add_to_menu
    draft = current_user.menus.status_draft.recent.first

    if draft.nil?
      redirect_to recipe, alert: "Aucun menu brouillon en cours. Générez d'abord un menu."
      return
    end

    menu_recipe = draft.menu_recipes.new(recipe: recipe, number_of_people: draft.default_people)

    if menu_recipe.save
      redirect_to draft, notice: "\"#{recipe.name}\" ajoutée au menu."
    else
      redirect_to recipe, alert: menu_recipe.errors.full_messages.to_sentence
    end
  end

  private

  # Accès mémoïsé à la recette courante — évite l'InstanceVariableAssumption dans chaque action
  def recipe
    @recipe ||= Recipe.find(params[:id])
  end

  def set_recipe
    recipe
  end

  def authorize_recipe
    authorize recipe
  end

  # Construit le scope de base avec filtre favoris si demandé (UC5)
  def recipes_base_scope
    scope = policy_scope(Recipe)
    return scope unless params[:favorites] == "true" && current_user

    scope.joins(:favorite_recipes)
         .where(favorite_recipes: { user_id: current_user.id })
  end

  # Charge les données liées à l'utilisateur connecté pour la vue show
  def load_user_recipe_data
    @is_favorited = recipe.favorited_by?(current_user)
    @user_review = recipe.reviews.find_by(user: current_user)
  end

  def redirect_with_favorite_notice(added)
    notice = added ? "Recette ajoutée à vos favoris ⭐" : "Recette retirée de vos favoris"
    redirect_to recipe, notice: notice
  end

  def render_favorite_turbo_stream(added)
    favorite_btn_id = "favorite-btn-#{recipe.id}"
    render turbo_stream: turbo_stream.replace(
      favorite_btn_id,
      partial: "recipes/favorite_button",
      locals: {
        recipe: recipe,
        is_favorited: added,
        container_id: favorite_btn_id,
        compact: params[:compact] == "true",
        show_page: params[:show_page] == "true"
      }
    )
  end

  # Paramètres autorisés pour Recipe
  # Accepte les nested attributes pour preparations (ingrédients avec quantités)
  def recipe_params
    params.require(:recipe).permit(
      :name, :description, :instructions,
      :default_servings, :prep_time_minutes, :cook_time_minutes,
      :difficulty, :price, :diet, :appliance, :source_url, :photo,
      tag_ids: [],
      preparations_attributes: preparation_permitted_fields
    )
  end

  def preparation_permitted_fields
    [ :id, :ingredient_id, :quantity_base, :_destroy ]
  end
end
