# frozen_string_literal: true

require "rails_helper"

# Normalisation des attributs saisis à la main, avant validation. Ingredient et
# Recipe partagent ce concern : les deux portent un nom tapé au clavier.
RSpec.describe AttributeCleaner do
  describe "nettoyage du nom" do
    # Le cas qui a fait doublon en base : « Persil frais » créé depuis le
    # formulaire d'import, à côté du « Persil frais » de la seed. L'unicité
    # compare des chaînes, elle ne les rapprochait pas.
    it "retire les espaces qui entourent un nom d'ingrédient" do
      ingredient = create(:ingredient, name: "  Persil frais ")

      expect(ingredient.name).to eq("Persil frais")
    end

    it "réduit aussi les espaces multiples au milieu" do
      expect(create(:ingredient, name: "Persil   frais").name).to eq("Persil frais")
    end

    it "fait alors jouer l'unicité contre le nom déjà en base" do
      create(:ingredient, name: "Persil frais")
      double = build(:ingredient, name: "Persil frais ")

      expect(double).not_to be_valid
      expect(double.errors[:name]).to include("existe déjà")
    end

    it "nettoie le nom d'une recette de la même façon" do
      recipe = create(:recipe, :with_ingredient, name: " Tarte  aux pommes ")

      expect(recipe.name).to eq("Tarte aux pommes")
    end

    # Un nom réduit à des espaces n'est pas un nom : il repasse à nil pour que
    # la validation de présence le voie, plutôt que de passer pour rempli.
    it "ramène un nom fait d'espaces à l'absence de nom" do
      ingredient = build(:ingredient, name: "   ")

      expect(ingredient).not_to be_valid
      expect(ingredient.name).to be_nil
      expect(ingredient.errors[:name]).to include("ne peut pas être vide")
    end
  end
end
