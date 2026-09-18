# frozen_string_literal: true

# La pop-up « Mes habituelles » de la liste de courses (UC8, étape 3) : on y
# décoche ce dont on n'a pas besoin cette fois, on ajuste une quantité, et le
# reste rejoint la liste, chaque article dans son rayon.
#
# Mêmes droits que l'ajout d'un article (GroceryItemPolicy#create?) : être
# membre du foyer du menu.
class UsualGroceryAdditionsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_menu

  # GET /menus/:menu_id/grocery_items/usual
  # Le contenu de la pop-up, chargé à chaque ouverture (turbo-frame).
  def new
    @usual_items   = @menu.household.usual_grocery_items.includes(:ingredient).sorted.to_a
    @already_added = @usual_items.select { |usual_item| usual_item.added_to?(@menu) }.to_set
    @one_off_count = @menu.grocery_items.one_off.count if @usual_items.empty?
  end

  # POST /menus/:menu_id/grocery_items/usual
  # Ajoute les articles retenus, puis revient sur la liste à jour avec le bilan.
  def create
    summary = Groceries::AddUsualItemsService.call(menu: @menu, selections: selections)
    flash_type = summary.any_added? ? :notice : :alert

    redirect_to grocery_menu_path(@menu), flash_type => summary.message, status: :see_other
  end

  private

  def set_menu
    @menu = Menu.find(params[:menu_id])
    authorize GroceryItem.new(menu: @menu), :create?
  end

  # Les articles cochés dans la pop-up, chacun avec la quantité de cette fois.
  # Un id qui n'est pas celui d'une course habituelle du foyer du menu est ignoré.
  # @return [Hash{UsualGroceryItem => BigDecimal}]
  def selections
    chosen = params.permit(items: [ :selected, :quantity ]).fetch(:items, {}).to_h
                   .select { |_id, item| item[:selected] == "1" && item[:quantity].to_d.positive? }

    @menu.household.usual_grocery_items.sorted.where(id: chosen.keys)
         .to_h { |usual_item| [ usual_item, chosen[usual_item.id.to_s][:quantity].to_d ] }
  end
end
