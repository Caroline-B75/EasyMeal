# Gestion des items de la liste de courses (GroceryItem)
# Toutes les actions sont nestées sous /menus/:menu_id/grocery_items.
# Les items :generated sont produits par BuildForMenuService (non modifiables manuellement).
# Les items :manual sont créés ici et peuvent être édités/supprimés librement.
class GroceryItemsController < ApplicationController
  include TurboFlashable

  before_action :authenticate_user!
  before_action :set_menu
  before_action :set_grocery_item, only: [ :update, :destroy ]
  before_action :authorize_grocery_item, only: [ :update, :destroy ]

  # POST /menus/:menu_id/grocery_items
  # UC3 : Ajout manuel d'un item à la liste de courses.
  #
  # Trois issues, décidées par le service : la ligne est créée, l'article y
  # était déjà (on le signale sans rien écrire), ou la saisie est refusée.
  def create
    authorize @menu.grocery_items.new, :create?

    result = Groceries::AddManualItemService.call(menu: @menu, params: grocery_item_create_params)
    @grocery_item = result.item

    case result.status
    when :created   then respond_success(redirect_path: @menu)
    when :duplicate then respond_notice(result.message, redirect_path: @menu)
    else                 respond_error(@grocery_item, redirect_path: @menu)
    end
  end

  # PATCH /menus/:menu_id/grocery_items/:id
  # UC3 : Cocher/décocher un item ou modifier sa quantité/unité
  def update
    if @grocery_item.update(grocery_item_update_params)
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

  # Seuls quantité, unité, état coché et libellé sont modifiables
  def grocery_item_update_params
    params.require(:grocery_item).permit(:quantity_base, :base_unit, :unit_group, :checked, :name)
  end
end
