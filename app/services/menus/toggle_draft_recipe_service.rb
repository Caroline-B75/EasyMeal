# frozen_string_literal: true

module Menus
  # Toggle ajout/retrait d'une recette dans un menu brouillon (UC2/UC7).
  #
  # Le toggle s'évalue dans son contexte de moment (UC7, chapitre 4) : depuis
  # le catalogue filtré « Goûters », seul un exemplaire tagué goûter compte —
  # la même recette peut donc rejoindre le menu au goûter ET au dîner. Sans
  # contexte (navigation libre), n'importe quel exemplaire fait foi et l'ajout
  # crée un repas sans moment, rangé avec les déjeuners dans le brouillon
  # (MealCounts::UNTYPED_MEAL_TYPE).
  #
  # @example
  #   result = Menus::ToggleDraftRecipeService.call(draft: menu, recipe: recipe, meal_type: "snack")
  #   result.added # => true ou false
  class ToggleDraftRecipeService
    Result = Struct.new(:added, keyword_init: true)

    # @param draft [Menu] Menu brouillon
    # @param recipe [Recipe] Recette à ajouter/retirer
    # @param meal_type [String, nil] Moment du contexte d'ajout, déjà passé en
    #   liste blanche MealTypes::MEAL_TYPES par l'appelant ; nil hors contexte
    # @return [Result]
    def self.call(draft:, recipe:, meal_type: nil)
      new(draft: draft, recipe: recipe, meal_type: meal_type).call
    end

    def initialize(draft:, recipe:, meal_type: nil)
      @draft = draft
      @recipe = recipe
      @meal_type = meal_type
    end

    def call
      existing = existing_menu_recipe

      if existing
        existing.destroy!
        Result.new(added: false)
      else
        @draft.append_meal!(recipe: @recipe, meal_type: @meal_type)
        Result.new(added: true)
      end
    end

    private

    # L'exemplaire visé par le retrait : un repas du moment du contexte s'il y
    # en a un, n'importe lequel sinon.
    def existing_menu_recipe
      scope = @draft.menu_recipes.where(recipe: @recipe)
      scope = scope.for_meal(@meal_type) if @meal_type
      scope.first
    end
  end
end
