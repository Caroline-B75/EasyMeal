# frozen_string_literal: true

require "rails_helper"

RSpec.describe Quantities::ScaleService do
  # Factories ou setup manuel pour les tests
  let(:ingredient_pates) do
    Ingredient.new(id: 1, name: "Pâtes", unit_group: "mass", base_unit: "g", category: "feculents")
  end

  let(:ingredient_oeufs) do
    Ingredient.new(id: 2, name: "Œufs", unit_group: "count", base_unit: "pièce", category: "produits_frais")
  end

  let(:ingredient_huile) do
    Ingredient.new(id: 3, name: "Huile d'olive", unit_group: "spoon", base_unit: "càc", category: "condiments")
  end

  let(:recipe) do
    recipe = Recipe.new(
      id: 1,
      name: "Pâtes à l'huile",
      default_servings: 4,
      diet: "omnivore"
    )
    # Simule les préparations
    allow(recipe).to receive(:preparations).and_return([
      Preparation.new(recipe: recipe, ingredient: ingredient_pates, quantity_base: 400),
      Preparation.new(recipe: recipe, ingredient: ingredient_oeufs, quantity_base: 2),
      Preparation.new(recipe: recipe, ingredient: ingredient_huile, quantity_base: 3)
    ])
    recipe
  end

  describe ".call" do
    context "avec le même nombre de personnes que la recette" do
      it "retourne les quantités inchangées" do
        result = described_class.call(recipe: recipe, servings: 4)

        expect(result.length).to eq(3)

        pates = result.find { |r| r[:ingredient].name == "Pâtes" }
        expect(pates[:quantity_base]).to eq(400)
        expect(pates[:quantity_display]).to eq("400 g")

        oeufs = result.find { |r| r[:ingredient].name == "Œufs" }
        expect(oeufs[:quantity_base]).to eq(2)
        expect(oeufs[:quantity_display]).to eq("2")
      end
    end

    context "avec le double de personnes" do
      it "double les quantités" do
        result = described_class.call(recipe: recipe, servings: 8)

        pates = result.find { |r| r[:ingredient].name == "Pâtes" }
        expect(pates[:quantity_base]).to eq(800)
        expect(pates[:quantity_display]).to eq("800 g")

        oeufs = result.find { |r| r[:ingredient].name == "Œufs" }
        expect(oeufs[:quantity_base]).to eq(4)
        expect(oeufs[:quantity_display]).to eq("4")

        huile = result.find { |r| r[:ingredient].name == "Huile d'olive" }
        expect(huile[:quantity_base]).to eq(6)
        expect(huile[:quantity_display]).to eq("2 càs") # 6 càc = 2 càs
      end
    end

    context "avec la moitié de personnes" do
      it "divise les quantités par 2" do
        result = described_class.call(recipe: recipe, servings: 2)

        pates = result.find { |r| r[:ingredient].name == "Pâtes" }
        expect(pates[:quantity_base]).to eq(200)
        expect(pates[:quantity_display]).to eq("200 g")

        oeufs = result.find { |r| r[:ingredient].name == "Œufs" }
        expect(oeufs[:quantity_base]).to eq(1)
        expect(oeufs[:quantity_display]).to eq("1")
      end
    end

    context "avec un facteur non entier" do
      it "calcule correctement les fractions" do
        result = described_class.call(recipe: recipe, servings: 6) # factor = 1.5

        pates = result.find { |r| r[:ingredient].name == "Pâtes" }
        expect(pates[:quantity_base]).to eq(600)
        expect(pates[:quantity_display]).to eq("600 g")

        oeufs = result.find { |r| r[:ingredient].name == "Œufs" }
        expect(oeufs[:quantity_base]).to eq(3)
        expect(oeufs[:quantity_display]).to eq("3")
      end
    end

    context "avec conversion d'unités" do
      it "convertit les grammes en kilogrammes au-delà de 1000g" do
        result = described_class.call(recipe: recipe, servings: 12) # factor = 3

        pates = result.find { |r| r[:ingredient].name == "Pâtes" }
        expect(pates[:quantity_base]).to eq(1200)
        expect(pates[:quantity_display]).to eq("1,2 kg")
      end
    end

    context "informations retournées" do
      it "inclut toutes les informations nécessaires" do
        result = described_class.call(recipe: recipe, servings: 4)

        item = result.first

        expect(item).to have_key(:ingredient)
        expect(item).to have_key(:quantity_base)
        expect(item).to have_key(:quantity_display)
        expect(item).to have_key(:unit)
        expect(item).to have_key(:category)
      end
    end
  end
end
