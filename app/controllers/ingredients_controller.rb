# Gestion des ingrédients
# Index visible par tous (pour l'auto-complétion), CRUD réservé aux admins
class IngredientsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_ingredient, only: [:show, :edit, :update, :destroy]
  before_action :authorize_ingredient, only: [:show, :edit, :update, :destroy]

  # GET /ingredients
  def index
    authorize Ingredient
    ingredients = policy_scope(Ingredient)
                    .alphabetical

    # Filtrage par recherche
    ingredients = ingredients.search(params[:query]) if params[:query].present?
    
    # Filtrage par catégorie
    ingredients = ingredients.by_category(params[:category]) if params[:category].present?
    
    # Filtrage par saison
    if params[:seasonal] == "true"
      # Ingrédients de saison pour le mois actuel
      ingredients = ingredients.in_season_for_month(Date.today.month)
    elsif params[:month].present?
      # Ingrédients de saison pour un mois spécifique
      ingredients = ingredients.in_season_for_month(params[:month])
    end
    
    # Pagination avec Pagy
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

  def authorize_ingredient
    authorize @ingredient
  end

  def ingredient_params
    permitted = params.require(:ingredient).permit(
      :name,
      :category,
      :unit_group,
      :base_unit,
      :aliases,
      season_months: [],
      aliases: []
    )
    
    # Convertir aliases en tableau si c'est une chaîne
    if permitted[:aliases].is_a?(String)
      permitted[:aliases] = permitted[:aliases].split(',').map(&:strip).reject(&:blank?)
    end
    
    # Nettoyer season_months : supprimer les valeurs vides et convertir en entiers
    if permitted[:season_months].present?
      permitted[:season_months] = permitted[:season_months].reject(&:blank?).map(&:to_i)
    end
    
    permitted
  end
end