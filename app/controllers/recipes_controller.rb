# Gestion des recettes (CRUD)
# Index & show : accessibles à tous (UC4, UC5)
# Create/Update/Destroy : réservés aux admins (gestion du catalogue)
class RecipesController < ApplicationController
  before_action :authenticate_user!, except: [:index, :show]
  before_action :set_recipe, only: [:show, :edit, :update, :destroy, :toggle_favorite, :add_review, :remove_review]
  before_action :authorize_recipe, only: [:show, :edit, :update, :destroy]

  # GET /recipes
  # UC5 : Catalogue & Recherche de recettes avec filtres
  def index
    authorize Recipe
    
    # Base de la requête avec policy scope
    recipes = policy_scope(Recipe)
    
    # Recherche textuelle (nom, ingrédients, tags)
    recipes = recipes.search(params[:query]) if params[:query].present?
    
    # Filtres par régime alimentaire
    recipes = recipes.for_diet(params[:diet]) if params[:diet].present?
    
    # Filtres par difficulté
    recipes = recipes.by_difficulty(params[:difficulty]) if params[:difficulty].present?
    
    # Filtres additionnels
    recipes = recipes.seasonal_for_month(Date.current.month) if params[:seasonal] == "true"
    recipes = recipes.with_total_time_lte(params[:max_time]) if params[:max_time].present?
    recipes = recipes.with_ingredient_names(params[:include_ingredients]) if params[:include_ingredients].present?
    recipes = recipes.without_ingredient_names(params[:exclude_ingredients]) if params[:exclude_ingredients].present?
    
    # Eager loading pour éviter les N+1 queries
    recipes = recipes.includes(:tags, :ingredients, photo_attachment: :blob)
    
    # Tri (défaut : alphabétique)
    recipes = recipes.order(params[:sort] || :name)
    
    # Pagination avec Pagy
    @pagy, @recipes = pagy(recipes, items: 20)
    
    # Pour Ransack (formulaire avancé si besoin ultérieur)
    @q = policy_scope(Recipe).ransack(params[:q])
  end

  # GET /recipes/:id
  # UC4 : Fiche recette avec ingrédients, étapes, interactions (favoris, notes)
  def show
    # Calcul du nombre de portions (par défaut : default_servings de la recette)
    @servings = (params[:servings] || @recipe.default_servings).to_i
    
    # Vérifier si la recette est en favori pour l'utilisateur connecté
    @is_favorited = current_user && @recipe.favorited_by?(current_user)
    
    # Récupérer l'avis de l'utilisateur connecté s'il existe
    @user_review = current_user ? @recipe.reviews.find_by(user: current_user) : nil
    
    # Charger les avis (paginés)
    @pagy_reviews, @reviews = pagy(@recipe.reviews.recent.includes(:user), items: 10)
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
    # Ajouter 1 preparation vide si aucune n'existe (pour faciliter l'ajout)
    @recipe.preparations.build if @recipe.preparations.empty?
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
        @is_favorited = added
      end
    end
  end

  # POST /recipes/:id/add_review
  # UC4 : Ajoute ou met à jour un avis
  def add_review
    @review = Review.create_or_update_for(
      user: current_user,
      recipe: @recipe,
      rating: params[:rating].to_i,
      content: params[:content]
    )

    if @review.persisted?
      respond_to do |format|
        format.turbo_stream do
          render turbo_stream: [
            turbo_stream.update("review-form-container", ""),
            turbo_stream.prepend("reviews-list", partial: "recipes/review_card", locals: { review: @review, current_user: current_user })
          ]
        end
        format.html { redirect_to @recipe, notice: "Ton avis a été enregistré 🌟" }
      end
    else
      redirect_to @recipe, alert: "Erreur : #{@review.errors.full_messages.join(', ')}"
    end
  end

  # DELETE /recipes/:id/remove_review
  # UC4 : Supprime l'avis de l'utilisateur
  def remove_review
    review = @recipe.reviews.find_by(user: current_user)
    
    if review&.destroy
      respond_to do |format|
        format.turbo_stream do
          render turbo_stream: [
            turbo_stream.remove("review_#{review.id}"),
            turbo_stream.update("review-form-container", partial: "recipes/review_form", locals: { recipe: @recipe })
          ]
        end
        format.html { redirect_to @recipe, notice: "Ton avis a été supprimé" }
      end
    else
      redirect_to @recipe, alert: "Impossible de supprimer l'avis"
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
      :name,
      :description,
      :instructions,
      :default_servings,
      :prep_time_minutes,
      :cook_time_minutes,
      :difficulty,
      :price,
      :diet,
      :appliance,
      :source_url,
      :photo,
      tag_ids: [],
      preparations_attributes: [
        :id,
        :ingredient_id,
        :quantity_base,
        :_destroy
      ]
    )
  end
end
