# frozen_string_literal: true

module Menus
  # Ajoute un repas aléatoire à un menu existant (UC1/UC2).
  #
  # Délègue la sélection de la recette à CandidatePickerService
  # (priorité saison → hors saison, anti-doublon).
  # Lève Menus::NoCandidatesError si aucune recette n'est disponible.
  #
  # Le nouveau repas est initialisé avec menu.default_people personnes.
  #
  # @example
  #   menu_recipe = Menus::AddRandomMealService.call(menu: @menu)
  #   # => MenuRecipe (persisted)
  class AddRandomMealService
    # @param menu [Menu]
    # @return [MenuRecipe] Nouveau repas persisté
    # @raise [Menus::NoCandidatesError]
    def self.call(menu:)
      new(menu: menu).call
    end

    def initialize(menu:)
      @menu = menu
    end

    def call
      recipe = CandidatePickerService.call(menu: @menu)

      next_position = @menu.menu_recipes.maximum(:position).to_i + 1
      @menu.menu_recipes.create!(
        recipe:           recipe,
        number_of_people: @menu.default_people,
        position:         next_position
      )
    end
  end
end
