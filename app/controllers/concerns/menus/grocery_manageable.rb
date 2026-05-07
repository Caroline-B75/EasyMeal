# UC3 — Gestion de la liste de courses
module Menus
  module GroceryManageable
    extend ActiveSupport::Concern

    # GET /menus/:id/grocery
    def grocery
      unless @menu.status_active?
        redirect_to @menu, alert: "La liste de courses n'est disponible que pour un menu actif."
        return
      end
      @grocery_items = @menu.grocery_items.sorted
    end

    # POST /menus/:id/regenerate_grocery
    # Supprime et recrée tous les GroceryItems générés depuis les recettes du menu.
    def regenerate_grocery
      unless @menu.status_active?
        redirect_to @menu, alert: "La liste de courses n'est disponible que pour un menu actif."
        return
      end

      Groceries::BuildForMenuService.call(menu: @menu)
      @grocery_items = @menu.grocery_items.sorted

      respond_to do |format|
        format.turbo_stream
        format.html { redirect_to grocery_menu_path(@menu), notice: "Liste de courses régénérée." }
      end
    end

  end
end
