# Gestion des recettes (CRUD)
# Index & show : accessibles à tous (UC4, UC5)
# Create/Update/Destroy : réservés aux admins (gestion du catalogue)
# Actions sociales (favoris, brouillon) : extraites dans des concerns
class RecipesController < ApplicationController
  include TurboFlashable
  include Recipes::Favoritable
  include Recipes::DraftManageable

  # Recettes par page du catalogue
  PER_PAGE = 20

  # Suggestions proposées quand la détection IA hésite : au-delà de deux, la
  # ligne cesse d'être un choix et redevient une liste à parcourir.
  AI_FUZZY_SUGGESTIONS = 2

  before_action :authenticate_user!, except: [ :index, :show ]
  before_action :authorize_recipe, only: [ :show, :edit, :update, :destroy, :publish ]

  # GET /recipes
  # UC5 : Catalogue & Recherche de recettes avec filtres
  def index
    authorize Recipe
    @catalog = Recipes::CatalogQuery.call(scope: recipes_base_scope, params: params, user: current_user) do |recipes|
      pagy(recipes, items: PER_PAGE)
    end
    load_draft_data
    # Vignettes du rail « menu à valider » affiché à côté des résultats
    load_draft_meals
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
    ingredients_data.map { |ing| ai_match_for(ing) }
  end

  # Une ligne du panneau : ce que l'IA a détecté, l'ingrédient du catalogue qui
  # lui correspond (ou les suggestions à départager), et surtout si la quantité
  # détectée sait rejoindre l'unité de base de chaque candidat — c'est ce
  # dernier point qui déclenche l'avertissement à l'écran.
  def ai_match_for(ingredient_data)
    name    = ingredient_data["name"].to_s
    qty     = ingredient_data["quantity"].to_f
    unit    = ingredient_data["unit"].to_s.presence
    matches = IngredientMatcherService.match(name)
    exact   = matches[:exact]

    # Conversion impossible → la quantité brute part quand même dans le
    # formulaire, à ajuster : mieux vaut un nombre à corriger qu'un champ vide.
    converted = exact && UnitConversionService.convert(quantity: qty, from_unit: unit, ingredient: exact)

    {
      ai_name:       name,
      quantity:      qty,
      unit:          unit,
      quantity_base: (converted || qty).round(2),
      converted:     converted.present?,
      exact:         exact,
      fuzzy:         suggestions_for(matches[:fuzzy], unit)
    }
  end

  # Les suggestions à départager, chacune accompagnée de sa compatibilité avec
  # l'unité détectée. Le découpage vit ici et non dans la vue : elle ne fait que
  # dérouler ce que le contrôleur a préparé.
  def suggestions_for(fuzzy_matches, unit)
    fuzzy_matches.first(AI_FUZZY_SUGGESTIONS).map do |ingredient|
      { ingredient: ingredient,
        converts:   UnitConversionService.compatible?(from_unit: unit, ingredient: ingredient) }
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
