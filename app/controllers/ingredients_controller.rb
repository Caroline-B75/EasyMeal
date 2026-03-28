# Gestion des ingrédients
# Index visible par tous (pour l'auto-complétion), CRUD réservé aux admins
class IngredientsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_ingredient, only: [ :show, :edit, :update, :destroy ]
  before_action :authorize_ingredient, only: [ :show, :edit, :update, :destroy ]

  # GET /ingredients
  def index
    authorize Ingredient
    ingredients = apply_filters(policy_scope(Ingredient).alphabetical)
    @pagy, @ingredients = pagy(ingredients, items: 20)
  end

  # GET /ingredients/:id
  def show
  end

  # GET /ingredients/new
  def new
    @ingredient = Ingredient.new
    authorize @ingredient
  end

  # GET /ingredients/:id/edit
  def edit
  end

  # POST /ingredients
  def create
    @ingredient = Ingredient.new(ingredient_params)
    authorize @ingredient

    if @ingredient.save
      redirect_to ingredients_path, notice: "Ingrédient créé avec succès."
    else
      render :new, status: :unprocessable_entity
    end
  end

  # POST /ingredients/quick_create
  # Création rapide d'un ingrédient depuis le formulaire recette (AJAX)
  # Retourne un Turbo Stream avec l'ingrédient créé
  def quick_create
    @ingredient = Ingredient.new(ingredient_params)
    authorize @ingredient, :create?

    if @ingredient.save
      render_quick_create_success
    else
      render_quick_create_error
    end
  end

  # PATCH/PUT /ingredients/:id
  def update
    if @ingredient.update(ingredient_params)
      redirect_to ingredients_path, notice: "Ingrédient mis à jour avec succès."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  # DELETE /ingredients/:id
  def destroy
    @ingredient.destroy
    redirect_to ingredients_path, notice: "Ingrédient supprimé avec succès."
  end

  private

  def set_ingredient
    @ingredient = Ingredient.find(params[:id])
  end

  def apply_filters(scope)
    scope = scope.search(params[:query])          if params[:query].present?
    scope = scope.by_category(params[:category])  if params[:category].present?
    apply_season_filter(scope)
  end

  def apply_season_filter(scope)
    if params[:seasonal] == "true"
      scope.in_season_for_month(Date.today.month)
    elsif params[:month].present?
      scope.in_season_for_month(params[:month])
    else
      scope
    end
  end

  def authorize_ingredient
    authorize @ingredient
  end

  def render_quick_create_success
    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: turbo_stream.append("ingredient-created-notification",
          partial: "ingredients/quick_create_success",
          locals: { ingredient: @ingredient }
        )
      end
      format.html { redirect_to ingredients_path, notice: "Ingrédient créé avec succès." }
    end
  end

  def render_quick_create_error
    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: turbo_stream.update("quick-ingredient-form",
          partial: "ingredients/quick_form",
          locals: { ingredient: @ingredient }
        ), status: :unprocessable_entity
      end
      format.html { render :new, status: :unprocessable_entity }
    end
  end

  # Paramètres autorisés pour Ingredient
  # Le nettoyage des données (aliases, season_months) est géré automatiquement
  # par le concern AttributeCleaner dans le model
  def ingredient_params
    params.require(:ingredient).permit(
      :name,
      :category,
      :unit_group,
      :base_unit,
      season_months: [],
      aliases: []
    )
  end
end
