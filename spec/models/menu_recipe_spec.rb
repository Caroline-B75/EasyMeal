# frozen_string_literal: true

require "rails_helper"

RSpec.describe MenuRecipe, type: :model do
  let(:user)   { create(:user) }
  let(:menu)   { create(:menu, user: user) }
  let(:recipe) { create(:recipe, :with_ingredient, meal_types: %w[breakfast]) }

  describe "MEAL_TYPES" do
    # equal et non eq : c'est la constante partagée elle-même qu'on veut ici,
    # pas une seconde liste qui lui ressemblerait aujourd'hui. Son contenu est
    # décrit une seule fois, dans le spec du concern MealTypes.
    it "reprend le vocabulaire partagé sans en redéfinir un second" do
      expect(described_class::MEAL_TYPES).to equal(MealTypes::MEAL_TYPES)
    end
  end

  describe "validation du moment" do
    it "accepte un apéro" do
      expect(build(:menu_recipe, menu: menu, recipe: recipe, meal_type: "apero")).to be_valid
    end

    it "accepte l'absence de moment" do
      expect(build(:menu_recipe, menu: menu, recipe: recipe, meal_type: nil)).to be_valid
    end

    it "refuse un moment inconnu" do
      expect(build(:menu_recipe, menu: menu, recipe: recipe, meal_type: "brunch")).not_to be_valid
    end
  end

  describe "répétition d'une recette dans un menu (UC7)" do
    it "autorise la même recette plusieurs fois : une brioche, sept matins heureux" do
      create(:menu_recipe, menu: menu, recipe: recipe)

      duplicate = build(:menu_recipe, menu: menu, recipe: recipe)

      expect(duplicate).to be_valid
      expect { duplicate.save! }.to change { menu.menu_recipes.count }.by(1)
    end
  end

  describe "#display_meal_type" do
    it "renvoie son propre moment quand il est renseigné" do
      meal = build(:menu_recipe, menu: menu, recipe: recipe, meal_type: "dinner")
      expect(meal.display_meal_type).to eq("dinner")
    end

    it "retombe sur le moment neutre (déjeuner) quand aucun moment n'est renseigné" do
      meal = build(:menu_recipe, menu: menu, recipe: recipe, meal_type: nil)
      expect(meal.display_meal_type).to eq("lunch")
    end
  end
end
