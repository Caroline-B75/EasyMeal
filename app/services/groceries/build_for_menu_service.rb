# frozen_string_literal: true

module Groceries
  # Service pour construire une liste de courses agrégée à partir d'un menu
  # Combine les quantités de tous les ingrédients identiques de toutes les recettes du menu
  #
  # Fonctionnalités :
  # - Agrège les quantités d'un même ingrédient utilisé dans plusieurs recettes
  # - Adapte les quantités au nombre de personnes de chaque recette
  # - Groupe par catégorie d'ingrédient pour faciliter les courses
  # - Retourne des quantités humanisées (g→kg, ml→L, etc.)
  #
  # Exemple d'usage :
  #   menu = Menu.find(1)
  #   grocery_list = Groceries::BuildForMenuService.call(menu: menu)
  #   # => [
  #   #   { ingredient: <Ingredient:pâtes>, quantity_base: 600, quantity_display: "600 g", category: "féculents" },
  #   #   { ingredient: <Ingredient:oeufs>, quantity_base: 9, quantity_display: "9", category: "produits_frais" }
  #   # ]
  #
  class BuildForMenuService
    # === Point d'entrée ===
    # @param menu [Menu] Le menu pour lequel générer la liste de courses
    # @return [Array<Hash>] Liste d'ingrédients agrégés avec quantités
    def self.call(menu:)
      new(menu: menu).call
    end

    def initialize(menu:)
      @menu = menu
    end

    def call
      return [] if @menu.menu_recipes.empty?

      aggregate_ingredients
        .map { |ingredient_id, data| format_result(data) }
        .sort_by { |item| [category_order(item[:category]), item[:ingredient].name] }
    end

    private

    # === Agrégation des quantités par ingrédient ===
    # Parcourt toutes les recettes du menu et accumule les quantités
    def aggregate_ingredients
      aggregated = Hash.new { |h, k| h[k] = { ingredient: nil, quantity_base: 0.0 } }

      # Précharge les données pour éviter les N+1 queries
      menu_recipes = @menu.menu_recipes.includes(recipe: { preparations: :ingredient })

      menu_recipes.each do |menu_recipe|
        process_menu_recipe(menu_recipe, aggregated)
      end

      aggregated
    end

    # Traite une recette du menu et ajoute ses ingrédients à l'agrégation
    # @param menu_recipe [MenuRecipe] La recette avec son nombre de personnes
    # @param aggregated [Hash] Le hash d'agrégation en cours
    def process_menu_recipe(menu_recipe, aggregated)
      factor = menu_recipe.scale_factor

      menu_recipe.recipe.preparations.each do |preparation|
        ingredient = preparation.ingredient
        scaled_quantity = preparation.quantity_base * factor

        # Agrège les quantités pour le même ingrédient
        aggregated[ingredient.id][:ingredient] = ingredient
        aggregated[ingredient.id][:quantity_base] += scaled_quantity
      end
    end

    # === Formatage du résultat ===
    # Convertit les données agrégées en format lisible
    # @param data [Hash] { ingredient:, quantity_base: }
    # @return [Hash] Résultat formaté avec humanisation
    def format_result(data)
      ingredient = data[:ingredient]
      quantity = data[:quantity_base].round(3)

      humanized = Quantities::HumanizeService.call(
        quantity: quantity,
        unit_group: ingredient.unit_group
      )

      {
        ingredient: ingredient,
        ingredient_name: ingredient.name,
        quantity_base: quantity,
        quantity_display: humanized[:display],
        unit: humanized[:unit],
        category: ingredient.category
      }
    end

    # === Ordre d'affichage des catégories ===
    # Permet de trier les ingrédients par rayon de courses
    # @param category [String] Nom de la catégorie
    # @return [Integer] Ordre de tri
    def category_order(category)
      order = {
        "fruits_legumes" => 0,
        "produits_frais" => 1,
        "viandes_poissons" => 2,
        "cremerie" => 3,
        "epicerie" => 4,
        "feculents" => 5,
        "boissons" => 6,
        "surgeles" => 7,
        "condiments" => 8,
        "autre" => 99
      }
      order[category.to_s] || 50
    end
  end
end
