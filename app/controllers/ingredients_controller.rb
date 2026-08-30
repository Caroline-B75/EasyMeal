# Gestion des ingrédients
# Index visible par tous (pour l'auto-complétion), CRUD réservé aux admins
class IngredientsController < ApplicationController
  # Nombre de propositions renvoyées par la recherche JSON du panneau IA
  SEARCH_LIMIT = 10

  before_action :authenticate_user!
  before_action :set_ingredient, only: [ :show, :edit, :update, :destroy, :add_alias ]
  before_action :authorize_ingredient, only: [ :show, :edit, :update, :destroy ]

  # GET /ingredients
  def index
    authorize Ingredient
    # with_recipes_count : la colonne « Recettes » du catalogue, comptée en une
    # seule requête pour toute la page — et triable comme les autres.
    scope = policy_scope(Ingredient).with_recipes_count.sorted_by(params[:sort], params[:direction])
    @pagy, @ingredients = pagy(apply_filters(scope), items: 20)
    # Compté sur tout le catalogue et non sur la page filtrée : ce compteur
    # prévient qu'il reste des densités estimées à vérifier, il ne décrit pas la
    # liste affichée.
    @to_check_count = policy_scope(Ingredient).density_source_ai.count
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

  # PATCH /ingredients/:id/add_alias
  # Ajoute un alias à un ingrédient (appelé quand l'admin confirme un match approximatif IA)
  def add_alias
    authorize @ingredient, :update?
    alias_name = params[:alias].to_s.strip.downcase
    return render json: { error: "Alias vide" }, status: :bad_request if alias_name.blank?

    existing = Array(@ingredient.aliases)
    @ingredient.update(aliases: existing + [ alias_name ]) if learnable_alias?(alias_name, existing)
    render json: { ok: true }
  end

  # GET /ingredients/search?q=thym
  # Recherche JSON dans le catalogue (nom ou alias). Alimente l'association
  # manuelle d'une ligne du panneau IA, quand la détection n'a rien proposé
  # d'utilisable — sans obliger à créer un doublon de l'ingrédient existant.
  def search
    authorize Ingredient, :index?
    # Même réduction que le matcher : « brin de thym » cherche « thym ».
    query   = IngredientMatcherService.strip_quantifier(params[:q].to_s.strip.downcase)
    results = policy_scope(Ingredient).search(query).alphabetical.limit(SEARCH_LIMIT)
    render json: results.map { |ingredient| search_result_json(ingredient) }
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
  # Un ingrédient employé par une recette est retenu par son association
  # (dependent: :restrict_with_error) : `destroy` rend false au lieu de lever.
  # Sans ce test, l'admin lisait « supprimé avec succès » devant un ingrédient
  # toujours présent dans la liste.
  def destroy
    if @ingredient.destroy
      redirect_to ingredients_path, notice: "Ingrédient supprimé avec succès."
    else
      redirect_to ingredients_path, alert: destroy_blocked_message
    end
  end

  private

  def set_ingredient
    @ingredient = Ingredient.find(params[:id])
  end

  # Dire ce qui retient l'ingrédient, pas seulement que la suppression a échoué :
  # sans le décompte, l'admin ne sait pas par où commencer pour le libérer.
  def destroy_blocked_message
    "« #{@ingredient.name} » est utilisé dans #{@ingredient.recipes_usage_label} : " \
      "retire-le de ces recettes avant de le supprimer."
  end

  def apply_filters(scope)
    scope = scope.search(params[:query])          if params[:query].present?
    scope = scope.by_category(params[:category])  if params[:category].present?
    # Scope engendré par l'enum density_source : les densités estimées par l'IA,
    # celles qui attendent une vérification.
    scope = scope.density_source_ai               if params[:to_check] == "true"
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

  # Un alias déjà connu n'est pas réécrit, et il ne doit jamais usurper le nom
  # d'un autre ingrédient : la détection ne saurait plus lequel des deux
  # désigner. Dans ce cas l'association reste valable pour la recette en cours,
  # elle n'est simplement pas apprise.
  def learnable_alias?(alias_name, existing)
    return false if existing.include?(alias_name)

    !Ingredient.where.not(id: @ingredient.id).exists?([ "LOWER(name) = ?", alias_name ])
  end

  # La fiche que rend la recherche (cf. IngredientCatalog#search_result), plus
  # la seule chose qu'un modèle ne saurait pas construire : la route
  # d'apprentissage de l'alias, dont le panneau IA se sert pour retenir le nom
  # qu'il vient d'associer.
  def search_result_json(ingredient)
    ingredient.search_result.merge(add_alias_path: add_alias_ingredient_path(ingredient))
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
  # La provenance de la densité n'est jamais soumise par le formulaire : elle est
  # déduite de qui écrit. Une valeur qui passe par ici a été lue et enregistrée
  # par un humain — corrigée ou simplement confirmée —, elle est donc `manual` et
  # cesse de s'afficher « à vérifier ». Seul Ingredients::EstimateDensityJob écrit
  # `ai`. Un champ vidé efface les deux (cf. les validations d'Ingredient).
  def ingredient_params
    attributes = params.require(:ingredient).permit(
      :name,
      :category,
      :unit_group,
      :base_unit,
      :piece_weight_g,
      :piece_volume_ml,
      :piece_label,
      :piece_label_plural,
      :density_g_per_ml,
      season_months: [],
      aliases: []
    )
    return attributes unless attributes.key?(:density_g_per_ml)

    attributes.merge(density_source: attributes[:density_g_per_ml].present? ? :manual : nil)
  end
end
