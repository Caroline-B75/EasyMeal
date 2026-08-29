# frozen_string_literal: true

module Ingredients
  # Repère, dans ce que l'IA a lu d'une recette, les ingrédients dont la
  # conversion échoue faute de densité, et lance leur estimation.
  #
  # Appelé à la fin de l'import : l'estimation part donc avant que la page de
  # revue s'ouvre, sans que l'utilisatrice ait à la demander. Et aucun appel
  # n'est fait tant qu'une recette n'en a pas besoin — un catalogue de cinq
  # cents ingrédients ne se fait pas estimer d'un bloc, et ce qui est déjà
  # curaté dans la seed n'est jamais redemandé.
  #
  # Ce service ne décide pas de ce qu'une densité peut relier : il le demande à
  # UnitConversionService, qui seul sait quels ponts existent.
  class MissingDensityService
    # @param ai_ingredients [Array<Hash>] ingrédients lus par l'IA (ai_raw_data)
    # @return [Array<Ingredient>] ingrédients dont l'estimation a été lancée
    def self.call(ai_ingredients)
      new(ai_ingredients).call
    end

    def initialize(ai_ingredients)
      @ai_ingredients = Array(ai_ingredients)
    end

    def call
      ingredients_needing_density.each { |ingredient| EstimateDensityJob.perform_later(ingredient) }
    end

    private

    # Les ingrédients du catalogue visés par la recette, dédoublonnés : deux
    # lignes peuvent parler du même (« farine », « farine tamisée »), et deux
    # jobs concurrents feraient deux fois le même appel à l'IA.
    def ingredients_needing_density
      @ai_ingredients.filter_map { |data| ingredient_needing_density(data) }.uniq
    end

    # Ne retient que les lignes où la question a un sens : une unité qu'on sait
    # lire, un ingrédient du catalogue reconnu sans ambiguïté (un rapprochement
    # approximatif n'est pas encore tranché par l'utilisatrice), et une densité
    # qui débloquerait vraiment la conversion.
    def ingredient_needing_density(data)
      unit = Units.canonical(data["unit"])
      return nil if unit.blank?

      ingredient = IngredientMatcherService.match(data["name"].to_s)[:exact]
      return nil unless ingredient
      return nil unless UnitConversionService.density_would_help?(from_unit: unit, ingredient: ingredient)

      ingredient
    end
  end
end
