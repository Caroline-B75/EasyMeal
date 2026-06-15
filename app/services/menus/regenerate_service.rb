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
      month          = Date.current.month
      diet           = @menu.diet.to_s
      base           = Recipe.published.compatible_with(diet)
      seasonal_scope = base.seasonal_for_month(month)

      seasonal = Recipe.where(id: seasonal_scope.select(:id))
                       .order(Arel.sql("RANDOM()"))
                       .limit(@number_of_meals)
                       .to_a

      remaining = @number_of_meals - seasonal.size
      other = if remaining > 0
                base.where.not(id: seasonal_scope.select(:id))
                    .order(Arel.sql("RANDOM()"))
                    .limit(remaining)
                    .to_a
              else
                []
              end

      selection = seasonal + other
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
