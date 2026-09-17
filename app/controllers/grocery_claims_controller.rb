# frozen_string_literal: true

# « Je m'en occupe » : répartir la liste de courses entre les membres du foyer.
#
# Chacun ne prend que pour soi — on n'attribue pas un article à quelqu'un
# d'autre. Prendre un article déjà pris par un autre membre le lui reprend ;
# laisser ne rend libre que ce qu'on avait pris soi-même.
#
# Chaque réponse re-rend le rayon touché (Turbo Stream) ; les autres écrans
# ouverts sur la liste se rafraîchissent d'eux-mêmes (cf. GroceryItem).
class GroceryClaimsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_menu
  before_action :set_grocery_item, only: %i[claim_item release_item]
  before_action :set_category, only: %i[claim_section release_section]

  # PATCH /menus/:menu_id/grocery_items/:id/claim
  def claim_item
    @grocery_item.claim!(current_user)
    render_section(@grocery_item.category)
  end

  # DELETE /menus/:menu_id/grocery_items/:id/claim
  def release_item
    @grocery_item.release!(current_user)
    render_section(@grocery_item.category)
  end

  # PATCH /menus/:menu_id/grocery_items/claim_section
  def claim_section
    @menu.claim_grocery_section!(@category, current_user)
    render_section(@category)
  end

  # DELETE /menus/:menu_id/grocery_items/claim_section
  def release_section
    @menu.release_grocery_section!(@category, current_user)
    render_section(@category)
  end

  private

  # Répartir la liste, c'est y avoir accès : être membre du foyer du menu.
  def set_menu
    @menu = Menu.find(params[:menu_id])
    authorize @menu, :grocery?
  end

  def set_grocery_item
    @grocery_item = @menu.grocery_items.find(params[:id])
  end

  # Le rayon visé : une clé de l'enum, ou rien pour « Divers » (articles sans
  # rayon). Une clé inconnue est une requête forgée : 404.
  def set_category
    @category = params[:category].presence
    raise ActiveRecord::RecordNotFound if @category && !GroceryItem.categories.key?(@category)
  end

  def render_section(category)
    respond_to do |format|
      format.turbo_stream { render partial: "grocery_items/section", locals: { menu: @menu, category: category } }
      format.html { redirect_to grocery_menu_path(@menu), status: :see_other }
    end
  end
end
