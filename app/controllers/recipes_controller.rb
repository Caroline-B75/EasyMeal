# Gestion des recettes (CRUD)
# Index & show : accessibles à tous (UC4, UC5)
# Create/Update/Destroy : réservés aux admins (gestion du catalogue)
class RecipesController < ApplicationController
  before_action :authenticate_user!, except: [ :index, :show ]
  before_action :set_recipe, only: [ :show, :edit, :update, :destroy, :toggle_favorite ]
  before_action :authorize_recipe, only: [ :show, :edit, :update, :destroy ]

  # GET /recipes
  # UC5 : Catalogue & Recherche de recettes avec filtres
  def index
    authorize Recipe
    base_scope = policy_scope(Recipe)

    # Filtre favoris : restreindre à ses recettes favorites si demandé
    if params[:favorites] == "true" && current_user
      base_scope = base_scope.joins(:favorite_recipes)
                             .where(favorite_recipes: { user_id: current_user.id })
    end

    recipes = Recipes::FilterService.call(base_scope, params)
                .includes(:tags, :ingredients, photo_attachment: :blob)
                .order(params[:sort] || :name)

    @pagy, @recipes = pagy(recipes, items: 20)
    @tags = Tag.joins(:recipes).distinct.alphabetical
    @ransack_query = base_scope.ransack(params[:q])
  end

  # GET /recipes/:id
  # UC4 : Fiche recette avec ingrédients, étapes, interactions (favoris, notes)
  def show
    reviews = @recipe.reviews
    @servings = (params[:servings] || @recipe.default_servings).to_i
    @is_favorited = current_user && @recipe.favorited_by?(current_user)
    @user_review = current_user ? reviews.find_by(user: current_user) : nil
    @pagy_reviews, @reviews = pagy(reviews.recent.includes(:user), items: 10)
  end

  # GET /recipes/new
  # Formulaire de création (admin only)
  def new
    @recipe = Recipe.new
    authorize @recipe

    # Pré-créer 1 preparation vide pour le formulaire
    @recipe.preparations.build
  end

  # GET /recipes/:id/edit
  # Formulaire d'édition (admin only)
  def edit
    preparations = @recipe.preparations
    preparations.build if preparations.empty?
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
    if @recipe.update(recipe_params)
      redirect_to @recipe, notice: "Recette mise à jour avec succès."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  # DELETE /recipes/:id
  # Suppression d'une recette (admin only)
  def destroy
    @recipe.destroy
    redirect_to recipes_path, notice: "Recette supprimée avec succès."
  end

  # POST /recipes/:id/toggle_favorite
  # UC4 : Toggle favori (ajoute si absent, supprime si présent)
  def toggle_favorite
    added = FavoriteRecipe.toggle_for(user: current_user, recipe: @recipe)

    respond_to do |format|
      format.html do
        if added
          redirect_to @recipe, notice: "Recette ajoutée à vos favoris ⭐"
        else
          redirect_to @recipe, notice: "Recette retirée de vos favoris"
        end
      end
      format.turbo_stream do
        is_compact = params[:compact] == "true"
        render turbo_stream: turbo_stream.replace(
          "favorite-btn-#{@recipe.id}",
          partial: "recipes/favorite_button",
          locals: { recipe: @recipe, is_favorited: added, container_id: "favorite-btn-#{@recipe.id}", compact: is_compact }
        )
      end
    end
  end

  private

  def set_recipe
    @recipe = Recipe.find(params[:id])
  end

  def authorize_recipe
    authorize @recipe
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
