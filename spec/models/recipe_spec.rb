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

  # Deux lignes visant le même ingrédient n'existent qu'en mémoire au moment de
  # valider : l'unicité portée par Preparation interroge la base et ne les y
  # trouve pas. Sans la règle du modèle, c'est l'index qui refusait, en pleine
  # sauvegarde — une erreur 500 au lieu d'un formulaire à corriger.
  describe "un ingrédient, une ligne — validation" do
    let(:sauce_soja) { create(:ingredient, name: "Sauce soja") }

    # Une recette dont la liste porte les ingrédients passés en argument.
    def recipe_listing(*ingredients)
      build(:recipe).tap do |recipe|
        ingredients.each { |ingredient| recipe.preparations.build(ingredient: ingredient, quantity_base: 10) }
      end
    end

    it "refuse deux lignes neuves visant le même ingrédient, et le nomme" do
      recipe = recipe_listing(sauce_soja, sauce_soja)

      expect(recipe).not_to be_valid
      expect(recipe.errors[:base]).to include(
        "Sauce soja apparaît plusieurs fois dans la liste des ingrédients : " \
        "garde une seule ligne par ingrédient, en additionnant les quantités."
      )
    end

    it "refuse aussi sur un brouillon : l'index d'unicité ne l'exempte pas" do
      recipe = recipe_listing(sauce_soja, sauce_soja)
      recipe.status = :draft

      expect(recipe).not_to be_valid
      expect(recipe.errors[:base].first).to match(/apparaît plusieurs fois/)
    end

    it "nomme les deux ingrédients quand deux paires sont en double" do
      tofu = create(:ingredient, name: "Tofu ferme")
      recipe = recipe_listing(sauce_soja, tofu, sauce_soja, tofu)

      recipe.validate

      expect(recipe.errors[:base].first).to start_with("Sauce soja et Tofu ferme apparaissent plusieurs fois")
    end

    it "accepte deux ingrédients différents" do
      expect(recipe_listing(sauce_soja, create(:ingredient, name: "Tofu"))).to be_valid
    end

    it "ne compte pas la ligne que l'on vient de retirer : elle ne sera plus là" do
      recipe = create(:recipe, :with_ingredient)
      retiree = recipe.preparations.create!(ingredient: sauce_soja, quantity_base: 10)
      retiree.mark_for_destruction
      recipe.preparations.build(ingredient: sauce_soja, quantity_base: 25)

      recipe.validate

      expect(recipe.errors[:base]).to be_empty
    end

    it "ne compte pas les lignes restées sans ingrédient : elles sont à remplir, pas en double" do
      recipe = recipe_listing(sauce_soja)
      2.times { recipe.preparations.build(quantity_base: 10) }

      recipe.validate

      # Seule la règle de présence d'`ingredient_id`, portée par la ligne, parle ici.
      expect(recipe.errors[:base]).to be_empty
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
