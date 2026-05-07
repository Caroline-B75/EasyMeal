# frozen_string_literal: true

module Groceries
  # Génère et persiste les GroceryItem(source: :generated) d'un menu.
  #
  # Appelé automatiquement par Menu#activate! et depuis MenusController#regenerate_grocery
  # (lorsque l'utilisateur enregistre des modifications sur un menu actif — UC2).
  #
  # Algorithme :
  # 1. Supprimer les GroceryItems existants source: :generated (idempotent).
  # 2. Pour chaque MenuRecipe, calculer le facteur de portion et agréger
  #    les quantités par ingrédient (en unité de base).
  # 3. Créer un GroceryItem par ingrédient agrégé.
  #
  # Les GroceryItems source: :manual ne sont JAMAIS touchés.
  #
  # @example
  #   Groceries::BuildForMenuService.call(menu: menu)
  class BuildForMenuService
    # @param menu [Menu]
    # @return [void]
    def self.call(menu:)
      new(menu: menu).call
    end

    def initialize(menu:)
      @menu = menu
    end

    def call
      ActiveRecord::Base.transaction do
        # Supprime uniquement les lignes générées (les lignes manuelles sont conservées)
        @menu.grocery_items.generated.destroy_all

        aggregate_ingredients.each_value do |data|
          create_grocery_item(data)
        end
      end
    end

    private

    # Agrège les quantités par ingrédient sur tous les repas du menu.
    # @return [Hash<Integer, Hash>] { ingredient_id => { ingredient:, quantity_base: } }
    def aggregate_ingredients
      aggregated = Hash.new { |h, k| h[k] = { ingredient: nil, quantity_base: 0.0 } }

      # Préchargement pour éviter N+1 queries
      @menu.menu_recipes
           .includes(recipe: { preparations: :ingredient })
           .each do |menu_recipe|
        accumulate_menu_recipe(menu_recipe, aggregated)
      end

      aggregated
    end

    # Ajoute la contribution d'un repas à l'agrégation.
    def accumulate_menu_recipe(menu_recipe, aggregated)
      factor = menu_recipe.scale_factor

      menu_recipe.recipe.preparations.each do |preparation|
        ingredient = preparation.ingredient
        aggregated[ingredient.id][:ingredient]    = ingredient
        aggregated[ingredient.id][:quantity_base] += (preparation.quantity_base * factor)
      end
    end

    # Crée un GroceryItem persisté à partir des données agrégées d'un ingrédient.
    def create_grocery_item(data)
      ingredient    = data[:ingredient]
      quantity_base = data[:quantity_base].round(3)

      @menu.grocery_items.create!(
        ingredient:    ingredient,
        name:          ingredient.name,
        quantity_base: quantity_base,
        unit_group:    ingredient.unit_group,
        base_unit:     ingredient.base_unit,
        category:      ingredient.category,
        source:        :generated,
        checked:       false
      )
    end
  end
end
