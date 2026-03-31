# Gestion des menus (UC1 - Génération, UC2 - Personnalisation, UC3 - Liste de courses)
# Un menu est toujours persisté en base, même à l'état brouillon (status: :draft).
# La transition draft → active déclenche la génération de la liste de courses.
#
# Actions extraites dans des concerns pour limiter la complexité :
# - Menus::Customizable   → add_random_meal, replace_meal, regenerate  (UC2)
# - Menus::GroceryManageable → grocery, regenerate_grocery             (UC3)
class MenusController < ApplicationController
  include TurboFlashable
  include Menus::Customizable
  include Menus::GroceryManageable

  MEMBER_ACTIONS = %i[show edit update destroy activate reactivate
                      add_random_meal replace_meal grocery regenerate_grocery regenerate].freeze

  before_action :authenticate_user!
  before_action :set_menu, only: MEMBER_ACTIONS
  before_action :authorize_menu, only: MEMBER_ACTIONS

  # GET /menus
  def index
    authorize Menu
    @menus = policy_scope(Menu).recent.includes(menu_recipes: :recipe)
    classify_menus
  end

  # GET /menus/:id
  def show
    @menu_recipes = @menu.menu_recipes.includes(:recipe).by_position
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
    @menu = Menus::GenerateService.call(**generation_params)
    redirect_to @menu, notice: "Votre menu a été généré ! Personnalisez-le avant de valider.", status: :see_other
  rescue Menus::NoCandidatesError => error
    flash.now[:alert] = error.message
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
    transition_menu(:activate!, "Menu activé ! Votre liste de courses est prête.",
                                "Impossible d'activer le menu")
  end

  # POST /menus/:id/reactivate
  # Réactive un menu archivé : l'ancien menu actif est archivé,
  # celui-ci redevient actif et sa liste de courses est régénérée.
  def reactivate
    transition_menu(:reactivate!, "Menu réactivé ! Votre liste de courses a été mise à jour.",
                                  "Impossible de réactiver le menu")
  end

  private

  def set_menu
    @menu = Menu.find(params[:id])
  end

  def authorize_menu
    authorize @menu
  end

  # Répartit les menus chargés en catégories pour la vue index
  def classify_menus
    @draft    = @menus.find(&:status_draft?)
    @active   = @menus.find(&:status_active?)
    @archived = @menus.select(&:status_archived?)
  end

  # Paramètres utilisés par Menus::GenerateService
  def generation_params
    {
      user:            current_user,
      diet:            menu_params[:diet],
      default_people:  menu_params[:default_people].to_i,
      number_of_meals: menu_params[:number_of_meals].to_i,
      name:            menu_params[:name].presence
    }
  end

  # Transition d'état du menu (activate/reactivate) avec gestion d'erreur unifiée
  def transition_menu(method, success_notice, failure_prefix)
    @menu.public_send(method)
    redirect_to @menu, notice: success_notice, status: :see_other
  rescue StandardError => error
    redirect_to @menu, alert: "#{failure_prefix} : #{error.message}", status: :see_other
  end

  # Paramètres pour la génération et re-génération d'un menu
  def menu_params
    params.require(:menu).permit(:name, :diet, :default_people, :number_of_meals)
  end

  # Paramètres pour la mise à jour d'un menu (nom, personnes par défaut)
  def menu_update_params
    params.require(:menu).permit(:name, :default_people)
  end
end
