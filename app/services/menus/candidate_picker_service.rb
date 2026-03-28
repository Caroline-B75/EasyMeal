# frozen_string_literal: true

module Menus
  # Service interne (non appelé directement depuis les contrôleurs) qui encapsule
  # la logique de tirage d'une recette candidate pour l'ajout ou le remplacement.
  #
  # Algorithme (UC1/UC2 — règle "priorité saison") :
  # 1. Tenter de piocher dans le pool "de saison" du mois courant en excluant
  #    les recettes déjà présentes dans le menu.
  # 2. Si le pool saison est épuisé, tenter dans le pool hors saison.
  # 3. Si les deux sont épuisés → lève Menus::NoCandidatesError.
  #
  # Le paramètre extra_excluded_ids permet d'exclure temporairement une recette
  # supplémentaire (ex : l'ancienne recette lors d'un remplacement, si on veut
  # s'assurer qu'elle n'est pas re-tirée immédiatement).
  class CandidatePickerService
    # @param menu [Menu] Le menu en cours (fournit diet + present_recipe_ids)
    # @param extra_excluded_ids [Array<Integer>] IDs supplémentaires à exclure
    # @return [Recipe]
    # @raise [Menus::NoCandidatesError]
    def self.call(menu:, extra_excluded_ids: [])
      new(menu: menu, extra_excluded_ids: extra_excluded_ids).call
    end

    def initialize(menu:, extra_excluded_ids: [])
      @menu = menu
      @extra_excluded_ids = extra_excluded_ids
    end

    def call
      excluded_ids = present_recipe_ids + @extra_excluded_ids
      month = Date.current.month

      # Tentative 1 : pool de saison
      candidate = seasonal_pool(month).where.not(id: excluded_ids).sample
      # Tentative 2 : pool hors saison
      candidate ||= offseason_pool(month).where.not(id: excluded_ids).sample

      candidate || raise(Menus::NoCandidatesError)
    end

    private

    # Recettes compatibles ET de saison pour le mois courant
    def seasonal_pool(month)
      Recipe.compatible_with(@menu.diet).seasonal_for_month(month)
    end

    # Recettes compatibles ET hors saison (ou sans info de saison)
    def offseason_pool(month)
      seasonal_ids = seasonal_pool(month).select(:id)
      Recipe.compatible_with(@menu.diet).where.not(id: seasonal_ids)
    end

    # IDs des recettes déjà présentes dans ce menu
    def present_recipe_ids
      @present_recipe_ids ||= @menu.menu_recipes.pluck(:recipe_id)
    end
  end
end
