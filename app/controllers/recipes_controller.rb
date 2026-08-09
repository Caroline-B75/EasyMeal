# Gestion des recettes (CRUD)
# Index & show : accessibles à tous (UC4, UC5)
# Create/Update/Destroy : réservés aux admins (gestion du catalogue)
# Actions sociales (favoris, brouillon) : extraites dans des concerns
class RecipesController < ApplicationController
  include TurboFlashable
  include Recipes::Favoritable
  include Recipes::DraftManageable

  before_action :authenticate_user!, except: [ :index, :show ]
  before_action :set_recipe, only: [ :show, :edit, :update, :destroy, :toggle_favorite, :toggle_in_draft, :publish ]
  before_action :authorize_recipe, only: [ :show, :edit, :update, :destroy, :publish ]

  # GET /recipes
  # UC5 : Catalogue & Recherche de recettes avec filtres
  def index
    authorize Recipe
    recipes = Recipes::FilterService.call(recipes_base_scope, params)
                .includes(:tags, :reviews, :photo_attachment)
                .order(params[:sort] || :name)
    @pagy, @recipes = pagy(recipes, items: 20)
    @recipes = @recipes.to_a
    @tags = Rails.cache.fetch("tags/with_recipes", expires_in: 1.hour) do
      Tag.joins(:recipes).distinct.alphabetical.to_a
    end
    @favorited_ids = if current_user
      Set.new(FavoriteRecipe.where(user: current_user, recipe_id: @recipes.map(&:id)).pluck(:recipe_id))
    else
      Set.new
    end
    # Badge « De saison » sur les cartes : on précalcule en UNE requête les IDs
    # de recettes de saison ce mois-ci, plutôt que d'appeler seasonal_for_month?
    # par carte (les ingrédients ne sont pas eager-loaded → éviterait un N+1).
    @current_month = Date.current.month
    @seasonal_ids = if @recipes.any?
      Set.new(Recipe.seasonal_for_month(@current_month).where(id: @recipes.map(&:id)).pluck(:id))
    else
      Set.new
    end
    load_draft_data
    # Vignettes du rail « menu à valider » affiché à côté des résultats
    load_draft_recipes
  end

  # GET /recipes/:id
  # UC4 : Fiche recette avec ingrédients, étapes, interactions (favoris, notes)
  def show
    @servings = (params[:servings] || recipe.default_servings).to_i
    # Liste à plat, dans l'ordre de saisie de la recette (les rayons ne servent
    # qu'à la liste de courses, pas à la fiche recette).
    @preparations = recipe.preparations.includes(:ingredient).order(:id)
    load_user_recipe_data if current_user
    # État « déjà dans le menu brouillon » : pilote le CTA (Ajouter / Retirer).
    load_draft_data
    @in_draft = @draft.present? && @draft_recipe_ids.include?(recipe.id)
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
    @ai_matches = compute_ai_matches if recipe.draft?
  end

  # PATCH /recipes/:id/publish
  # Publie un brouillon (admin only)
  def publish
    if recipe.update(status: :published)
      redirect_to recipe, notice: "Recette publiée et visible dans le catalogue !"
    else
      redirect_to edit_recipe_path(recipe),
        alert: "Impossible de publier : #{recipe.errors.full_messages.to_sentence}"
    end
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
  # Mise à jour d'une recette (admin only).
  # Si _publish=1 est soumis (bouton "Publier"), sauvegarde ET publie en une seule requête.
  def update
    attrs = recipe_params
    attrs = attrs.merge(status: :published) if params[:_publish].present?

    if recipe.update(attrs)
      if recipe.published? && params[:_publish].present?
        redirect_to recipe, notice: "Recette publiée et visible dans le catalogue !"
      else
        redirect_to edit_recipe_path(recipe), notice: "Brouillon sauvegardé."
      end
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

  # Calcule les correspondances IA pour chaque ingrédient suggéré (recette brouillon)
  def compute_ai_matches
    ingredients_data = recipe.ai_raw_data&.fetch("ingredients", []) || []
    ingredients_data.map do |ing|
      name    = ing["name"].to_s
      qty     = ing["quantity"].to_f
      unit    = ing["unit"].to_s.presence
      matches = IngredientMatcherService.match(name)
      quantity_base = if matches[:exact]
        UnitConversionService.convert(quantity: qty, from_unit: unit, ingredient: matches[:exact]) || qty
      else
        qty
      end
      {
        ai_name:       name,
        quantity:      qty,
        unit:          unit,
        quantity_base: quantity_base.round(2),
        exact:         matches[:exact],
        fuzzy:         matches[:fuzzy]
      }
    end
  end

  # Paramètres autorisés pour Recipe
  # Accepte les nested attributes pour preparations (ingrédients avec quantités)
  def recipe_params
    params.require(:recipe).permit(
      :name, :description, :instructions,
      :default_servings, :prep_time_minutes, :cook_time_minutes,
      :difficulty, :price, :diet, :appliance, :source_url, :photo,
      tag_ids: [], meal_types: [],
      preparations_attributes: [ :id, :ingredient_id, :quantity_base, :_destroy ]
    )
  end
end
