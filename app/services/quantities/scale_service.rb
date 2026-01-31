# frozen_string_literal: true

module Quantities
  # Service pour calculer les quantités d'ingrédients adaptées au nombre de personnes
  #
  # Formule centrale : quantity_scaled = quantity_base × (servings / default_servings)
  #
  # @example Recette pour 4 personnes, on veut pour 6
  #   Quantities::ScaleService.call(recipe: recipe, servings: 6)
  #   # => [{ ingredient: <Ingredient>, quantity_base: 300.0, display: "300 g" }, ...]
  #
  class ScaleService
    # Point d'entrée principal (class method)
    def self.call(recipe:, servings:)
      new(recipe: recipe, servings: servings).call
    end

    def initialize(recipe:, servings:)
      @recipe = recipe
      @servings = servings.to_i
      @servings = 1 if @servings < 1 # Minimum 1 personne
    end

    # Retourne un tableau d'ingrédients avec leurs quantités adaptées
    # @return [Array<Hash>] Liste des ingrédients avec quantités calculées
    def call
      @recipe.preparations.includes(:ingredient).map do |preparation|
        build_scaled_item(preparation)
      end
    end

    # Calcule le facteur de mise à l'échelle
    # @return [Float] Le ratio servings_demandées / servings_par_défaut
    def factor
      @factor ||= @servings.to_f / @recipe.default_servings
    end

    private

    # Construit un item avec toutes les informations nécessaires
    def build_scaled_item(preparation)
      ingredient = preparation.ingredient
      scaled_quantity = scale_quantity(preparation.quantity_base)

      # Humaniser la quantité pour l'affichage
      humanized = Quantities::HumanizeService.call(
        quantity: scaled_quantity,
        unit_group: ingredient.unit_group
      )

      {
        ingredient: ingredient,
        preparation: preparation,
        quantity_base: scaled_quantity,
        quantity_display: humanized[:display],
        unit: humanized[:unit],
        category: ingredient.category
      }
    end

    # Applique le facteur de mise à l'échelle
    def scale_quantity(quantity_base)
      (quantity_base.to_f * factor).round(3)
    end
  end
end
