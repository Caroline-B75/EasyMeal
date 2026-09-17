# UC3 — Gestion de la liste de courses
module Menus
  module GroceryManageable
    extend ActiveSupport::Concern

    UNAVAILABLE_ALERT = "La liste de courses n'est disponible que pour un menu actif.".freeze

    # GET /menus/:id/grocery
    #
    # Reste ouverte pendant qu'un membre du foyer modifie le menu : sa liste
    # existe toujours, et quelqu'un peut être en train de faire les courses avec.
    # La vue prévient alors que la revalidation la mettra à jour.
    def grocery
      unless @menu.status_active? || @menu.pending_revalidation?
        redirect_to @menu, alert: UNAVAILABLE_ALERT
        return
      end
      @grocery_items = @menu.grocery_items.for_list
    end

    # POST /menus/:id/regenerate_grocery
    # Supprime et recrée tous les GroceryItems générés depuis les recettes du menu.
    # Réservé au menu actif : sur un brouillon, c'est la revalidation qui
    # reconstruit la liste.
    def regenerate_grocery
      unless @menu.status_active?
        redirect_to @menu, alert: UNAVAILABLE_ALERT
        return
      end

      Groceries::BuildForMenuService.call(menu: @menu)
      @grocery_items = @menu.grocery_items.for_list

      respond_to do |format|
        format.turbo_stream
        format.html { redirect_to grocery_menu_path(@menu), notice: "Liste de courses régénérée." }
      end
    end
  end
end
