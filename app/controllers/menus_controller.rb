# Gestion des menus (UC1 - Génération, UC2 - Personnalisation, UC3 - Liste de courses)
# Un menu est toujours persisté en base, même à l'état brouillon (status: :draft).
# La transition draft → active déclenche la génération de la liste de courses.
class MenusController < ApplicationController
  before_action :authenticate_user!
  before_action :set_menu, only: [ :show, :edit, :update, :destroy,
                                   :activate, :reactivate, :add_random_meal, :replace_meal, :regenerate_grocery ]
  before_action :authorize_menu, only: [ :show, :edit, :update, :destroy,
                                         :activate, :reactivate, :add_random_meal, :replace_meal, :regenerate_grocery ]

  # GET /menus
  def index
    authorize Menu
    @menus = policy_scope(Menu).recent.includes(menu_recipes: :recipe)
    @draft    = @menus.find(&:status_draft?)
    @active   = @menus.find(&:status_active?)
    @archived = @menus.select(&:status_archived?)
    # Sépare les 3 premiers menus archivés (visibles) des plus anciens (masqués)
    @recent_archived = @archived.first(3)
    @older_archived  = @archived.drop(3)
  end

  # GET /menus/:id
  def show
    @menu_recipes = @menu.menu_recipes.includes(:recipe).order(:id)
    @grocery_items = @menu.grocery_items.sorted if @menu.status_active?
  end

  # GET /menus/new
  def new
    @menu = Menu.new(
      diet:           current_user.default_diet,
      default_people: current_user.default_people
    )
    authorize @menu
  end

  # POST /menus
  # UC1 : Génère un menu brouillon et le persiste immédiatement
  def create
    authorize Menu
    @menu = Menus::GenerateService.call(
      user:           current_user,
      diet:           menu_params[:diet],
      default_people: menu_params[:default_people].to_i,
      number_of_meals: menu_params[:number_of_meals].to_i,
      name:           menu_params[:name].presence
    )
    redirect_to @menu, notice: "Votre menu a été généré ! Personnalisez-le avant de valider.", status: :see_other
  rescue Menus::NoCandidatesError => e
    flash.now[:alert] = e.message
    @menu = Menu.new(menu_params.except(:number_of_meals))
    render :new, status: :unprocessable_entity
  end

  # GET /menus/:id/edit
  def edit; end

  # PATCH /menus/:id
  def update
    if @menu.update(menu_update_params)
      redirect_to @menu, notice: "Menu mis à jour.", status: :see_other
    else
      render :edit, status: :unprocessable_entity
    end
  end

  # DELETE /menus/:id
  def destroy
    @menu.destroy
    redirect_to menus_path, notice: "Menu supprimé.", status: :see_other
  end

  # POST /menus/:id/activate
  # UC1 : Valide le menu brouillon et génère la liste de courses
  # Archive automatiquement l'éventuel menu actif précédent
  def activate
    @menu.activate!
    redirect_to @menu, notice: "Menu activé ! Votre liste de courses est prête.", status: :see_other
  rescue => e
    redirect_to @menu, alert: "Impossible d'activer le menu : #{e.message}", status: :see_other
  end

  # POST /menus/:id/reactivate
  # Réactive un menu archivé : l'ancien menu actif est archivé,
  # celui-ci redevient actif et sa liste de courses est régénérée.
  def reactivate
    @menu.reactivate!
    redirect_to @menu, notice: "Menu réactivé ! Votre liste de courses a été mise à jour.", status: :see_other
  rescue => e
    redirect_to @menu, alert: "Impossible de réactiver le menu : #{e.message}", status: :see_other
  end

  # POST /menus/:id/add_random_meal
  # UC2 : Ajoute un repas aléatoire en tenant compte du régime et de la saison
  def add_random_meal
    @menu_recipe = Menus::AddRandomMealService.call(menu: @menu)
    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to @menu, status: :see_other }
    end
  rescue Menus::NoCandidatesError => e
    respond_to do |format|
      format.turbo_stream { render_flash_stream(alert: e.message) }
      format.html { redirect_to @menu, alert: e.message, status: :see_other }
    end
  end

  # POST /menus/:id/replace_meal
  # UC2 : Remplace un repas par un autre (params: menu_recipe_id)
  def replace_meal
    @old_menu_recipe = @menu.menu_recipes.find(params[:menu_recipe_id])
    @menu_recipe = Menus::ReplaceMealService.call(menu: @menu, menu_recipe: @old_menu_recipe)
    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to @menu }
    end
  rescue ActiveRecord::RecordNotFound
    redirect_to @menu, alert: "Ce repas est introuvable.", status: :see_other
  rescue Menus::NoCandidatesError => e
    respond_to do |format|
      format.turbo_stream { render_flash_stream(alert: e.message) }
      format.html { redirect_to @menu, alert: e.message, status: :see_other }
    end
  end

  # POST /menus/:id/regenerate_grocery
  # UC3 : Régénère les items générés de la liste de courses (préserve les items manuels)
  def regenerate_grocery
    Groceries::BuildForMenuService.call(menu: @menu)
    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to @menu, notice: "Liste de courses régénérée.", status: :see_other }
    end
  end

  private

  def set_menu
    @menu = Menu.find(params[:id])
  end

  def authorize_menu
    authorize @menu
  end

  # Rendu Turbo Stream d'un message flash (erreur servicielle)
  def render_flash_stream(alert:)
    render turbo_stream: turbo_stream.replace(
      "flash",
      partial: "shared/flash",
      locals: { flash: { alert: alert } }
    )
  end

  # Paramètres pour la génération d'un menu (UC1)
  def menu_params
    params.require(:menu).permit(:name, :diet, :default_people, :number_of_meals)
  end

  # Paramètres pour la mise à jour d'un menu (nom, personnes par défaut)
  def menu_update_params
    params.require(:menu).permit(:name, :default_people)
  end
end
