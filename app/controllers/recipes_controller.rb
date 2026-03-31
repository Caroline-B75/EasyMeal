# Gestion des recettes (CRUD)
# Index & show : accessibles à tous (UC4, UC5)
# Create/Update/Destroy : réservés aux admins (gestion du catalogue)
# Actions sociales (favoris, brouillon) : extraites dans des concerns
class RecipesController < ApplicationController
  include TurboFlashable
  include Recipes::Favoritable
  include Recipes::DraftManageable

  before_action :authenticate_user!, except: [ :index, :show ]
  before_action :set_recipe, only: [ :show, :edit, :update, :destroy, :toggle_favorite, :add_to_menu, :toggle_in_draft ]
  before_action :authorize_recipe, only: [ :show, :edit, :update, :destroy ]

  # GET /recipes
  # UC5 : Catalogue & Recherche de recettes avec filtres
  def index
    authorize Recipe
    recipes = Recipes::FilterService.call(recipes_base_scope, params)
                .includes(:tags, :ingredients, photo_attachment: :blob)
                .order(params[:sort] || :name)
    @pagy, @recipes = pagy(recipes, items: 20)
    @tags = Tag.joins(:recipes).distinct.alphabetical
    load_draft_data
  end

  # GET /recipes/:id
  # UC4 : Fiche recette avec ingrédients, étapes, interactions (favoris, notes)
  def show
    @servings = (params[:servings] || recipe.default_servings).to_i
    @preparations_by_category = recipe.preparations.includes(:ingredient)
                                      .group_by { |prep| prep.ingredient.category }
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

  private

  # Accès mémoïsé à la recette courante
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

  # Paramètres autorisés pour Recipe
  # Accepte les nested attributes pour preparations (ingrédients avec quantités)
  def recipe_params
    params.require(:recipe).permit(
      :name, :description, :instructions,
      :default_servings, :prep_time_minutes, :cook_time_minutes,
      :difficulty, :price, :diet, :appliance, :source_url, :photo,
      tag_ids: [],
      preparations_attributes: [ :id, :ingredient_id, :quantity_base, :_destroy ]
    )
  end
end
