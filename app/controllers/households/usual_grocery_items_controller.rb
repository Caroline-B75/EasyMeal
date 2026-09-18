# frozen_string_literal: true

module Households
  # Les courses habituelles du foyer (UC8, étape 3) : ce qu'il achète chaque
  # semaine ou presque, ajouté d'un bouton à la liste de courses (cf.
  # UsualGroceryAdditionsController).
  #
  # Toujours la liste du foyer du compte connecté : les articles sont cherchés
  # dans current_user.household, ce qui tient lieu d'autorisation (même principe
  # que HouseholdsController). Tous les membres la voient et la modifient.
  class UsualGroceryItemsController < ApplicationController
    before_action :authenticate_user!
    before_action :set_usual_grocery_item, only: %i[update destroy]

    # GET /foyer/courses-habituelles
    def index
      @usual_grocery_items = usual_grocery_items.sorted.includes(:ingredient)
    end

    # POST /foyer/courses-habituelles
    # Même formulaire que « Ajouter un article » sur la liste de courses.
    def create
      item = usual_grocery_items.create(usual_grocery_item_params)
      back_to_list(item, item.persisted?, notice: "« #{item.name} » ajouté à tes courses habituelles.")
    end

    # PATCH /foyer/courses-habituelles/:id
    # La quantité et l'unité ; pour changer d'article, on supprime et on ajoute.
    def update
      back_to_list(@usual_grocery_item, @usual_grocery_item.update(usual_grocery_item_update_params))
    end

    # DELETE /foyer/courses-habituelles/:id
    def destroy
      @usual_grocery_item.destroy
      back_to_list(@usual_grocery_item, true,
                   notice: "« #{@usual_grocery_item.name} » ne fait plus partie de tes courses habituelles.")
    end

    # POST /foyer/courses-habituelles/reprendre (params: menu_id)
    # Les ajouts ponctuels d'une liste de courses deviennent des habituels ; on
    # arrive ici pour vérifier ce qui a été repris.
    def import
      count = UsualGroceryItem.import_from(current_user.menus.find(params[:menu_id]))
      redirect_to household_usual_grocery_items_path, notice: import_notice(count), status: :see_other
    end

    private

    def usual_grocery_items
      current_user.household.usual_grocery_items
    end

    def set_usual_grocery_item
      @usual_grocery_item = usual_grocery_items.find(params[:id])
    end

    def usual_grocery_item_params
      params.require(:usual_grocery_item).permit(:name, :quantity, :unit, :category, :ingredient_id)
    end

    def usual_grocery_item_update_params
      params.require(:usual_grocery_item).permit(:quantity, :unit)
    end

    # @param count [Integer] articles repris
    def import_notice(count)
      return "Aucun nouvel article à reprendre." if count.zero?

      "#{count} #{count > 1 ? 'articles repris' : 'article repris'} de ta liste de courses : vérifie les quantités."
    end

    # Retour à la liste : le message de réussite, ou ce qui a empêché l'enregistrement
    def back_to_list(item, saved, notice: nil)
      flash_message = saved ? { notice: notice } : { alert: item.errors.full_messages.to_sentence }
      redirect_to household_usual_grocery_items_path, **flash_message, status: :see_other
    end
  end
end
