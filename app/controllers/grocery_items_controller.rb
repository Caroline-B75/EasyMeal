# Gestion des items de la liste de courses (GroceryItem)
# Toutes les actions sont nestées sous /menus/:menu_id/grocery_items.
# Les items :generated sont produits par BuildForMenuService (non modifiables manuellement).
# Les items :manual sont créés ici et peuvent être édités/supprimés librement.
class GroceryItemsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_menu
  before_action :set_grocery_item, only: [ :update, :destroy ]
  before_action :authorize_grocery_item, only: [ :update, :destroy ]

  # POST /menus/:menu_id/grocery_items
  # UC3 : Ajout manuel d'un item à la liste de courses
  def create
    @grocery_item = @menu.grocery_items.new(grocery_item_create_params.merge(source: :manual))
    authorize @grocery_item

    if @grocery_item.save
      respond_to do |format|
        format.turbo_stream
        format.html { redirect_to @menu }
      end
    else
      respond_to do |format|
        format.turbo_stream { render_flash_stream(alert: @grocery_item.errors.full_messages.to_sentence) }
        format.html { redirect_to @menu, alert: @grocery_item.errors.full_messages.to_sentence }
      end
    end
  end

  # PATCH /menus/:menu_id/grocery_items/:id
  # UC3 : Cocher/décocher un item ou modifier sa quantité/unité
  def update
    if @grocery_item.update(grocery_item_update_params)
      respond_to do |format|
        format.turbo_stream
        format.html { redirect_to @menu }
      end
    else
      respond_to do |format|
        format.turbo_stream { render_flash_stream(alert: @grocery_item.errors.full_messages.to_sentence) }
        format.html { redirect_to @menu, alert: @grocery_item.errors.full_messages.to_sentence }
      end
    end
  end

  # DELETE /menus/:menu_id/grocery_items/:id
  # Suppression d'un item (manual uniquement depuis l'UI ; generated via regenerate_grocery)
  def destroy
    @grocery_item.destroy
    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to @menu }
    end
  end

  private

  def set_menu
    @menu = Menu.find(params[:menu_id])
    authorize @menu, :show?
  end

  def set_grocery_item
    @grocery_item = @menu.grocery_items.find(params[:id])
  end

  def authorize_grocery_item
    authorize @grocery_item
  end

  def render_flash_stream(alert:)
    render turbo_stream: turbo_stream.replace(
      "flash",
      partial: "shared/flash",
      locals: { flash: { alert: alert } }
    )
  end

  # Paramètres pour la création d'un item manuel
  def grocery_item_create_params
    params.require(:grocery_item).permit(:name, :quantity_base, :base_unit, :unit_group, :category, :ingredient_id)
  end

  # Seuls quantité, unité, état coché et libellé sont modifiables
  def grocery_item_update_params
    params.require(:grocery_item).permit(:quantity_base, :base_unit, :unit_group, :checked, :name)
  end
end
