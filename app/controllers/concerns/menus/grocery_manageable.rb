# UC3 — Gestion de la liste de courses
module Menus
  module GroceryManageable
    extend ActiveSupport::Concern

    # GET /menus/:id/grocery
    # Page dédiée de la liste de courses (menu actif uniquement)
    def grocery
      unless @menu.status_active?
        redirect_to @menu, alert: "La liste de courses n'est disponible que pour un menu actif."
        return
      end
      @grocery_items = @menu.grocery_items.sorted
    end

    # POST /menus/:id/regenerate_grocery
    # Régénère les items générés de la liste de courses (préserve les items manuels)
    def regenerate_grocery
      Groceries::BuildForMenuService.call(menu: @menu)
      respond_to do |format|
        format.turbo_stream
        format.html { redirect_to @menu, notice: "Liste de courses régénérée.", status: :see_other }
      end
    end
  end
end
