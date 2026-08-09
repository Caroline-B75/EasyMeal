# frozen_string_literal: true

module Menus
  # Remplace un repas existant par une nouvelle recette tirée aléatoirement (UC2).
  #
  # Règles :
  # - La nouvelle recette est tirée via CandidatePickerService dans le pool du
  #   MÊME moment que le repas remplacé (UC7 : un dîner redonne un dîner),
  #   priorité saison, en excluant la recette remplacée et celles déjà
  #   présentes dans ce moment.
  # - Le nouveau repas reprend la place du remplacé : nombre de personnes,
  #   moment, position et jour annoté sont CONSERVÉS.
  # - L'ancien MenuRecipe est supprimé, un nouveau est créé.
  # - L'opération est atomique (transaction).
  #
  # Lève Menus::NoCandidatesError si aucune recette de remplacement n'est disponible.
  #
  # @example
  #   new_mr = Menus::ReplaceMealService.call(menu: @menu, menu_recipe: @menu_recipe)
  #   # => MenuRecipe (nouveau, persisted)
  class ReplaceMealService
    # @param menu [Menu]
    # @param menu_recipe [MenuRecipe] Le repas à remplacer
    # @return [MenuRecipe] Nouveau repas persisté
    # @raise [Menus::NoCandidatesError]
    def self.call(menu:, menu_recipe:)
      new(menu: menu, menu_recipe: menu_recipe).call
    end

    def initialize(menu:, menu_recipe:)
      @menu        = menu
      @menu_recipe = menu_recipe
    end

    def call
      new_recipe = pick_replacement

      # La place du repas remplacé, relevée AVANT sa suppression
      slot = @menu_recipe.slice(:number_of_people, :meal_type, :position, :day_of_week)

      ActiveRecord::Base.transaction do
        @menu_recipe.destroy!

        @menu.menu_recipes.create!(slot.merge(recipe: new_recipe))
      end
    end

    private

    # Tire dans le pool du moment du repas remplacé, sans re-tirer sa recette
    def pick_replacement
      CandidatePickerService.call(
        menu:               @menu,
        meal_type:          @menu_recipe.meal_type,
        extra_excluded_ids: [ @menu_recipe.recipe_id ]
      )
    end
  end
end
