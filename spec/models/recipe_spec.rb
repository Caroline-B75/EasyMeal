# frozen_string_literal: true

require "rails_helper"

RSpec.describe Recipe, type: :model do
  describe "moments du repas — validation (UC7)" do
    it "refuse une recette publiée qui n'annonce aucun moment" do
      recipe = build(:recipe, :with_ingredient, meal_types: [])

      expect(recipe).not_to be_valid
      expect(recipe.errors[:meal_types]).to include("doit comporter au moins un moment")
    end

    it "accepte un moment unique" do
      expect(build(:recipe, :with_ingredient, meal_types: %w[breakfast])).to be_valid
    end

    it "accepte plusieurs moments : une quiche vit au déjeuner ET au dîner" do
      expect(build(:recipe, :with_ingredient, meal_types: %w[lunch dinner])).to be_valid
    end

    it "exempte les brouillons, comme la règle « au moins un ingrédient »" do
      expect(build(:recipe, status: :draft, meal_types: [])).to be_valid
    end

    it "refuse un moment inconnu, y compris sur un brouillon" do
      recipe = build(:recipe, status: :draft, meal_types: %w[brunch])

      expect(recipe).not_to be_valid
      expect(recipe.errors[:meal_types].first).to match(/moment inconnu : brunch/)
    end

    it "ignore l'entrée vide fantôme des cases à cocher et les doublons" do
      recipe = build(:recipe, :with_ingredient, meal_types: [ "", "lunch", "lunch" ])

      expect(recipe).to be_valid
      expect(recipe.meal_types).to eq(%w[lunch])
    end
  end

  describe ".for_meal_type" do
    let!(:breakfast_recipe) { create(:recipe, :with_ingredient, meal_types: %w[breakfast snack]) }
    let!(:dinner_recipe)    { create(:recipe, :with_ingredient, meal_types: %w[dinner]) }

    it "retient les recettes dont l'array contient le moment demandé" do
      expect(described_class.for_meal_type("breakfast")).to contain_exactly(breakfast_recipe)
      expect(described_class.for_meal_type("dinner")).to contain_exactly(dinner_recipe)
    end

    it "retient une recette sur chacun de ses moments" do
      expect(described_class.for_meal_type("snack")).to contain_exactly(breakfast_recipe)
    end

    it "ne renvoie rien pour un moment que personne ne porte" do
      expect(described_class.for_meal_type("apero")).to be_empty
    end

    it "ne filtre pas quand aucun moment n'est demandé" do
      expect(described_class.for_meal_type(nil)).to contain_exactly(breakfast_recipe, dinner_recipe)
    end
  end

  describe "#draft_missing_fields" do
    it "réclame le moment du repas tant qu'aucun n'est coché" do
      draft = build(:recipe, status: :draft, meal_types: [])

      expect(draft.draft_missing_fields).to include("Moment du repas")
    end

    it "ne le réclame plus dès qu'un moment est coché" do
      draft = build(:recipe, status: :draft, meal_types: %w[apero])

      expect(draft.draft_missing_fields).not_to include("Moment du repas")
    end
  end
end
