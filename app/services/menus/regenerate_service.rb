# frozen_string_literal: true

module Menus
  # Re-génère les repas d'un menu brouillon existant.
  #
  # Appelé depuis MenusController#regenerate après mise à jour des paramètres
  # du menu (régime, nombre de personnes, etc.).
  # Les anciens MenuRecipes doivent être déjà supprimés avant l'appel.
  #
  # Utilise le même algorithme de sélection que GenerateService :
  # priorité saison, puis hors saison pour compléter.
  class RegenerateService
    # @param menu [Menu] Menu draft déjà mis à jour (diet, default_people, name)
    # @param number_of_meals [Integer] Nombre de repas à générer
    # @return [Menu] Le menu avec ses nouveaux MenuRecipes
    def self.call(menu:, number_of_meals:)
      new(menu: menu, number_of_meals: number_of_meals).call
    end

    def initialize(menu:, number_of_meals:)
      @menu            = menu
      @number_of_meals = number_of_meals.to_i
    end

    def call
      selection = pick_recipes
      build_menu_recipes(selection)
      @menu
    end

    private

    def pick_recipes
      month    = Date.current.month
      diet     = @menu.diet.to_s
      seasonal = Recipe.compatible_with(diet).seasonal_for_month(month).to_a.shuffle
      other    = Recipe.compatible_with(diet)
                       .where.not(id: seasonal.map(&:id))
                       .to_a.shuffle

      selection = (seasonal + other).first(@number_of_meals)
      raise Menus::NoCandidatesError if selection.empty?

      selection
    end

    def build_menu_recipes(selection)
      ActiveRecord::Base.transaction do
        selection.each_with_index do |recipe, index|
          @menu.menu_recipes.create!(
            recipe:           recipe,
            number_of_people: @menu.default_people,
            position:         index
          )
        end
      end
    end
  end
end
