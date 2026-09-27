# Gestion des items de la liste de courses (GroceryItem)
# Toutes les actions sont nestées sous /menus/:menu_id/grocery_items.
# Les items :generated sont produits par BuildForMenuService (non modifiables manuellement).
# Les items :manual sont créés ici et peuvent être édités/supprimés librement.
class GroceryItemsController < ApplicationController
  include TurboFlashable

  before_action :authenticate_user!
  before_action :set_menu
  before_action :set_grocery_item, only: [ :update, :destroy, :cancel_addition ]
  before_action :authorize_grocery_item, only: [ :update, :destroy, :cancel_addition ]

  # POST /menus/:menu_id/grocery_items
  # UC3 : Ajout manuel d'un item à la liste de courses.
  #
  # Le service crée la ligne, ou additionne la quantité à celle qui porte déjà
  # l'article ; dans les deux cas la liste est rendue à jour. Une addition se dit
  # par un message — la ligne a changé ailleurs dans la page —, qui offre de
  # l'annuler (cf. create.turbo_stream).
  def create
    authorize @menu.grocery_items.new, :create?

    result = Groceries::AddManualItemService.call(menu: @menu, params: grocery_item_create_params)
    @grocery_item = result.item
    return respond_error(@grocery_item, redirect_path: @menu) if result.status == :invalid

    @merged = result.status == :merged
    respond_success(redirect_path: @menu, notice: (helpers.grocery_merge_notice(@grocery_item) if @merged))
  end

  # DELETE /menus/:menu_id/grocery_items/:id/addition
  # « Annuler » du message qui suit une addition : la ligne revient à ce qu'elle
  # était, si personne n'y a touché depuis (cf. GroceryItem#undo!).
  def cancel_addition
    if @grocery_item.undo!(params[:token])
      respond_success(redirect_path: @menu, notice: "Ajout annulé.")
    else
      respond_error(@grocery_item, redirect_path: @menu)
    end
  end

  # PATCH /menus/:menu_id/grocery_items/:id
  # UC3 : Cocher/décocher un item ou modifier sa quantité/unité
  # Cocher donne l'article à qui le coche (« Je m'en occupe », cf. GroceryItem#assign_buyer).
  # Une quantité corrigée porte sur ce que la ligne doit aux ajouts à la main —
  # part habituelle ou part ajoutée en plus —, s'il y en a
  # (cf. GroceryItem#shift_quantity_change_to_added_parts).
  # Elle arrive telle que saisie, dans l'unité choisie (cf. GroceryItem#enter_quantity).
  def update
    @grocery_item.assign_attributes(grocery_item_update_params)
    return respond_error(@grocery_item, redirect_path: @menu) unless enter_quantity

    @grocery_item.assign_buyer(current_user)
    @grocery_item.shift_quantity_change_to_added_parts

    if @grocery_item.save
      respond_success(redirect_path: @menu)
    else
      respond_error(@grocery_item, redirect_path: @menu)
    end
  end

  # DELETE /menus/:menu_id/grocery_items/:id
  # Suppression d'un item (manual uniquement depuis l'UI ; generated via regenerate_grocery)
  def destroy
    @grocery_item.destroy
    respond_success(redirect_path: @menu)
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

  # Paramètres pour la création d'un item manuel.
  #
  # `quantity` et `unit` sont ce qui a été saisi — « 2 » et « kg » —, pas ce qui
  # sera stocké : c'est le service qui les ramène à l'unité de base de la ligne,
  # et qui décide de croire ou non le rayon selon que l'article est reconnu.
  def grocery_item_create_params
    params.require(:grocery_item).permit(:name, :quantity, :unit, :category, :ingredient_id)
  end

  # État coché, unité et libellé ; la quantité passe par enter_quantity.
  def grocery_item_update_params
    params.require(:grocery_item).permit(:base_unit, :unit_group, :checked, :name)
  end

  # La quantité corrigée, s'il y en a une : ce qui a été saisi — « 2 » et
  # « piece » —, que la ligne ramène à son unité de base.
  # @return [Boolean] false si l'unité ne convient pas à la ligne
  def enter_quantity
    entered = params.require(:grocery_item).permit(:quantity, :unit)
    return true unless entered.key?(:quantity)

    @grocery_item.enter_quantity(entered[:quantity], entered[:unit])
  end
end
