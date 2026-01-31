# frozen_string_literal: true

require "rails_helper"

RSpec.describe Groceries::BuildForMenuService do
  # Setup des ingrédients
  let(:ingredient_pates) do
    Ingredient.new(id: 1, name: "Pâtes", unit_group: "mass", base_unit: "g", category: "feculents")
  end

  let(:ingredient_tomates) do
    Ingredient.new(id: 2, name: "Tomates", unit_group: "count", base_unit: "pièce", category: "fruits_legumes")
  end

  let(:ingredient_huile) do
    Ingredient.new(id: 3, name: "Huile d'olive", unit_group: "spoon", base_unit: "càc", category: "condiments")
  end

  let(:ingredient_fromage) do
    Ingredient.new(id: 4, name: "Parmesan", unit_group: "mass", base_unit: "g", category: "cremerie")
  end

  # Setup des recettes
  let(:recipe_carbonara) do
    recipe = Recipe.new(id: 1, name: "Carbonara", default_servings: 4, diet: "omnivore")
    allow(recipe).to receive(:preparations).and_return([
      Preparation.new(recipe: recipe, ingredient: ingredient_pates, quantity_base: 400),
      Preparation.new(recipe: recipe, ingredient: ingredient_fromage, quantity_base: 100)
    ])
    recipe
  end

  let(:recipe_salade) do
    recipe = Recipe.new(id: 2, name: "Salade de tomates", default_servings: 2, diet: "vegan")
    allow(recipe).to receive(:preparations).and_return([
      Preparation.new(recipe: recipe, ingredient: ingredient_tomates, quantity_base: 4),
      Preparation.new(recipe: recipe, ingredient: ingredient_huile, quantity_base: 2)
    ])
    recipe
  end

  # Setup du menu
  let(:user) { User.new(id: 1, email: "test@test.com") }
  let(:menu) { Menu.new(id: 1, name: "Menu test", user: user) }

  describe ".call" do
    context "avec un menu vide" do
      before do
        allow(menu).to receive(:menu_recipes).and_return(MenuRecipe.none)
      end

      it "retourne une liste vide" do
        result = described_class.call(menu: menu)

        expect(result).to eq([])
      end
    end

    context "avec une seule recette" do
      before do
        menu_recipe = MenuRecipe.new(menu: menu, recipe: recipe_carbonara, number_of_people: 4)
        
        relation = double("relation")
        allow(relation).to receive(:empty?).and_return(false)
        allow(relation).to receive(:includes).and_return([menu_recipe])
        allow(menu).to receive(:menu_recipes).and_return(relation)
      end

      it "retourne les ingrédients de la recette" do
        result = described_class.call(menu: menu)

        expect(result.length).to eq(2)

        pates = result.find { |r| r[:ingredient_name] == "Pâtes" }
        expect(pates[:quantity_base]).to eq(400)
        expect(pates[:quantity_display]).to eq("400 g")

        fromage = result.find { |r| r[:ingredient_name] == "Parmesan" }
        expect(fromage[:quantity_base]).to eq(100)
        expect(fromage[:quantity_display]).to eq("100 g")
      end
    end

    context "avec plusieurs recettes partageant des ingrédients" do
      before do
        # Deux recettes qui utilisent les pâtes
        recipe_pates_tomates = Recipe.new(id: 3, name: "Pâtes tomates", default_servings: 4, diet: "vegan")
        allow(recipe_pates_tomates).to receive(:preparations).and_return([
          Preparation.new(recipe: recipe_pates_tomates, ingredient: ingredient_pates, quantity_base: 400),
          Preparation.new(recipe: recipe_pates_tomates, ingredient: ingredient_tomates, quantity_base: 6)
        ])

        menu_recipe1 = MenuRecipe.new(menu: menu, recipe: recipe_carbonara, number_of_people: 4)
        menu_recipe2 = MenuRecipe.new(menu: menu, recipe: recipe_pates_tomates, number_of_people: 4)
        
        relation = double("relation")
        allow(relation).to receive(:empty?).and_return(false)
        allow(relation).to receive(:includes).and_return([menu_recipe1, menu_recipe2])
        allow(menu).to receive(:menu_recipes).and_return(relation)
      end

      it "agrège les quantités des ingrédients identiques" do
        result = described_class.call(menu: menu)

        pates = result.find { |r| r[:ingredient_name] == "Pâtes" }
        # 400g (carbonara) + 400g (pâtes tomates) = 800g
        expect(pates[:quantity_base]).to eq(800)
        expect(pates[:quantity_display]).to eq("800 g")
      end

      it "retourne tous les ingrédients uniques" do
        result = described_class.call(menu: menu)

        ingredient_names = result.map { |r| r[:ingredient_name] }
        expect(ingredient_names).to include("Pâtes", "Parmesan", "Tomates")
        expect(result.length).to eq(3) # Pas de doublons
      end
    end

    context "avec des portions différentes" do
      before do
        # Carbonara pour 8 personnes (double)
        menu_recipe = MenuRecipe.new(menu: menu, recipe: recipe_carbonara, number_of_people: 8)
        
        relation = double("relation")
        allow(relation).to receive(:empty?).and_return(false)
        allow(relation).to receive(:includes).and_return([menu_recipe])
        allow(menu).to receive(:menu_recipes).and_return(relation)
      end

      it "adapte les quantités au nombre de personnes" do
        result = described_class.call(menu: menu)

        pates = result.find { |r| r[:ingredient_name] == "Pâtes" }
        expect(pates[:quantity_base]).to eq(800) # 400 * 2
        expect(pates[:quantity_display]).to eq("800 g")
      end
    end

    context "tri des résultats" do
      before do
        menu_recipe1 = MenuRecipe.new(menu: menu, recipe: recipe_carbonara, number_of_people: 4)
        menu_recipe2 = MenuRecipe.new(menu: menu, recipe: recipe_salade, number_of_people: 2)
        
        relation = double("relation")
        allow(relation).to receive(:empty?).and_return(false)
        allow(relation).to receive(:includes).and_return([menu_recipe1, menu_recipe2])
        allow(menu).to receive(:menu_recipes).and_return(relation)
      end

      it "trie par catégorie puis par nom" do
        result = described_class.call(menu: menu)

        categories = result.map { |r| r[:category] }
        # fruits_legumes (0) < cremerie (3) < feculents (5) < condiments (8)
        expect(categories).to eq(%w[fruits_legumes cremerie feculents condiments])
      end
    end

    context "format des résultats" do
      before do
        menu_recipe = MenuRecipe.new(menu: menu, recipe: recipe_carbonara, number_of_people: 4)
        
        relation = double("relation")
        allow(relation).to receive(:empty?).and_return(false)
        allow(relation).to receive(:includes).and_return([menu_recipe])
        allow(menu).to receive(:menu_recipes).and_return(relation)
      end

      it "inclut toutes les informations nécessaires" do
        result = described_class.call(menu: menu)
        item = result.first

        expect(item).to have_key(:ingredient)
        expect(item).to have_key(:ingredient_name)
        expect(item).to have_key(:quantity_base)
        expect(item).to have_key(:quantity_display)
        expect(item).to have_key(:unit)
        expect(item).to have_key(:category)
      end
    end
  end
end
