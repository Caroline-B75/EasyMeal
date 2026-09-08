require 'rails_helper'

RSpec.describe Preparation, type: :model do
  # De vraies associations, non persistées : la quantité affichée ne dépend que
  # du nombre de convives de la recette et de ce que le catalogue sait de
  # l'ingrédient.
  def preparation_for(quantity, **ingredient_attributes)
    build(:preparation,
          recipe:        build(:recipe, default_servings: 4),
          ingredient:    build(:ingredient, **ingredient_attributes),
          quantity_base: quantity)
  end

  describe "#humanized_quantity" do
    # Le concombre des wraps au poulet : un demi pour 4 personnes, 400 g pièce.
    let(:concombre) do
      { unit_group: :count, base_unit: "piece", piece_label: "pièce", piece_weight_g: 400 }
    end

    it "dit la demi-pièce que la recette consomme au lieu de l'arrondir à l'unité" do
      expect(preparation_for(0.5, **concombre).humanized_quantity(servings: 4))
        .to eq("0,5 pièce (200 g)")
    end

    it "suit le nombre de convives : doubler la table double la quantité" do
      expect(preparation_for(0.5, **concombre).humanized_quantity(servings: 8))
        .to eq("1 pièce (400 g)")
    end

    it "s'arrête au dixième de pièce, la mesure disant le reste" do
      expect(preparation_for(0.5, **concombre).humanized_quantity(servings: 3))
        .to eq("0,4 pièce (150 g)")
    end

    it "garde les pièces entières de ce qui se pèse — on sort 4 blancs du frigo" do
      poulet = { unit_group: :mass, base_unit: "g", piece_label: "blanc", piece_weight_g: 150 }

      expect(preparation_for(500, **poulet).humanized_quantity(servings: 4))
        .to eq("4 blancs pour 500 g")
    end

    it "se dit dans son unité quand le catalogue ne compte pas de pièces" do
      preparation = preparation_for(1500, unit_group: :mass, base_unit: "g")

      expect(preparation.humanized_quantity(servings: 4)).to eq("1,5 kg")
    end
  end
end
