# frozen_string_literal: true

module Menus
  # Remplace un repas existant par une nouvelle recette tirée aléatoirement (UC2).
  #
  # Règles :
  # - La nouvelle recette est choisie via CandidatePickerService (priorité saison,
  #   anti-doublon sur les recettes déjà présentes dans le menu).
  # - Le number_of_people du repas remplacé est CONSERVÉ sur le nouveau repas.
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
      # Mémoriser le nb de personnes AVANT suppression
      people = @menu_recipe.number_of_people

      # Choisir la nouvelle recette en excluant la recette actuelle du calcul des candidats
      # (elle sera supprimée, mais on l'exclut pour éviter de la re-tirer immédiatement)
      new_recipe = CandidatePickerService.call(
        menu:              @menu,
        extra_excluded_ids: [@menu_recipe.recipe_id]
      )

      ActiveRecord::Base.transaction do
        @menu_recipe.destroy!

        @menu.menu_recipes.create!(
          recipe:           new_recipe,
          number_of_people: people
        )
      end
    end
  end
end
