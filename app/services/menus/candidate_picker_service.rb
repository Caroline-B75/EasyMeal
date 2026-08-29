# frozen_string_literal: true

module Menus
  # Tire UNE recette candidate pour le remplacement 🔀 d'un repas dans un menu
  # existant (service interne, non appelé directement des contrôleurs).
  #
  # Le tirage (priorité saison du mois courant, puis hors saison) est délégué
  # à SeasonalDrawService, sur le pool des recettes publiées compatibles avec
  # le régime — restreint au moment demandé quand meal_type est fourni (UC7 :
  # le remplacement 🔀 d'un dîner redonne un dîner).
  #
  # Anti-doublon : la répétition étant permise dans un menu (UC7), seules les
  # recettes déjà présentes dans le MÊME moment sont écartées — une recette
  # peut vivre dans deux moments différents, pas deux fois dans le même.
  # extra_excluded_ids écarte en plus la recette en cours de remplacement,
  # pour qu'elle ne soit pas re-tirée immédiatement.
  class CandidatePickerService
    # @param menu [Menu] Le menu en cours (fournit le régime et les repas présents)
    # @param meal_type [String, nil] Moment du repas à servir (nil = repas sans moment)
    # @param extra_excluded_ids [Array<Integer>] IDs supplémentaires à exclure
    # @return [Recipe]
    # @raise [Menus::NoCandidatesError] quand le pool du moment est épuisé
    def self.call(menu:, meal_type:, extra_excluded_ids: [])
      new(menu: menu, meal_type: meal_type, extra_excluded_ids: extra_excluded_ids).call
    end

    def initialize(menu:, meal_type:, extra_excluded_ids:)
      @menu               = menu
      @meal_type          = meal_type
      @extra_excluded_ids = extra_excluded_ids
    end

    def call
      candidate = SeasonalDrawService.call(pool: pool, count: 1, excluded_ids: excluded_ids).first

      candidate || raise(Menus::NoCandidatesError)
    end

    private

    # Recettes publiées compatibles régime, restreintes au moment demandé
    # (for_meal_type laisse passer tout le catalogue quand meal_type est nil).
    def pool
      Recipe.published.compatible_with(@menu.diet).for_meal_type(@meal_type)
    end

    # Recettes déjà présentes dans CE moment du menu (pour un repas sans
    # moment, l'anti-doublon joue entre repas sans moment), plus les
    # exclusions ponctuelles de l'appelant.
    def excluded_ids
      @menu.menu_recipes.for_meal(@meal_type).pluck(:recipe_id) + @extra_excluded_ids
    end
  end
end
