# frozen_string_literal: true

module Menus
  # Toggle ajout/retrait d'une recette dans un menu brouillon (UC2).
  #
  # Si la recette est déjà dans le menu, la retire.
  # Sinon, l'ajoute en dernière position avec le nombre de personnes par défaut.
  #
  # @example
  #   result = Menus::ToggleDraftRecipeService.call(draft: menu, recipe: recipe)
  #   result.added # => true ou false
  class ToggleDraftRecipeService
    Result = Struct.new(:added, keyword_init: true)

    # @param draft [Menu] Menu brouillon
    # @param recipe [Recipe] Recette à ajouter/retirer
    # @return [Result]
    def self.call(draft:, recipe:)
      new(draft: draft, recipe: recipe).call
    end

    def initialize(draft:, recipe:)
      @draft = draft
      @recipe = recipe
    end

    def call
      existing = @draft.menu_recipes.find_by(recipe: @recipe)

      if existing
        existing.destroy!
        Result.new(added: false)
      else
        add_recipe_to_draft
        Result.new(added: true)
      end
    end

    private

    def add_recipe_to_draft
      next_position = @draft.menu_recipes.maximum(:position).to_i + 1
      @draft.menu_recipes.create!(
        recipe:           @recipe,
        number_of_people: @draft.default_people,
        position:         next_position
      )
    end
  end
end
