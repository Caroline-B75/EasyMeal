# frozen_string_literal: true

require "rails_helper"

RSpec.describe UnitConversionService do
  # Les ingrédients ne sont jamais sauvegardés ici : la conversion ne lit que
  # leur unité et leur poids unitaire.
  def ingredient(unit_group, base_unit, piece_weight_g: nil)
    build(:ingredient, unit_group: unit_group, base_unit: base_unit, piece_weight_g: piece_weight_g)
  end

  describe ".convert" do
    context "au sein d'un même groupe d'unités" do
      it "ramène une masse à des grammes" do
        expect(described_class.convert(quantity: 1.5, from_unit: "kg", ingredient: ingredient(:mass, "g")))
          .to eq(1500.0)
      end

      it "ramène un volume à des millilitres" do
        expect(described_class.convert(quantity: 20, from_unit: "cl", ingredient: ingredient(:volume, "ml")))
          .to eq(200.0)
      end

      it "ramène une cuillère à soupe à des cuillères à café" do
        expect(described_class.convert(quantity: 2, from_unit: "càs", ingredient: ingredient(:spoon, "cac")))
          .to eq(6.0)
      end

      # L'IA laisse l'unité vide pour ce qui se compte (« 3 oeufs »)
      it "traite l'absence d'unité comme un décompte" do
        expect(described_class.convert(quantity: 3, from_unit: nil, ingredient: ingredient(:count, "piece")))
          .to eq(3.0)
      end

      it "accepte une unité écrite en majuscules ou entourée d'espaces" do
        expect(described_class.convert(quantity: 1, from_unit: " L ", ingredient: ingredient(:volume, "ml")))
          .to eq(1000.0)
      end
    end

    context "d'un groupe à l'autre, par le poids unitaire" do
      # Le cas d'origine : la recette compte des tranches, le catalogue pèse.
      it "convertit un décompte en masse" do
        jambon = ingredient(:mass, "g", piece_weight_g: 40)

        expect(described_class.convert(quantity: 2, from_unit: nil, ingredient: jambon)).to eq(80.0)
      end

      it "convertit une masse en décompte" do
        oeuf = ingredient(:count, "piece", piece_weight_g: 50)

        expect(described_class.convert(quantity: 200, from_unit: "g", ingredient: oeuf)).to eq(4.0)
      end

      # La quantité rejoint d'abord l'unité de base de son propre groupe (kg → g)
      # avant de traverser : sans cela, 1 kg vaudrait 1 pièce.
      it "traverse depuis une unité dérivée" do
        oeuf = ingredient(:count, "piece", piece_weight_g: 50)

        expect(described_class.convert(quantity: 1, from_unit: "kg", ingredient: oeuf)).to eq(20.0)
      end

      it "renonce quand l'ingrédient n'a pas de poids unitaire" do
        expect(described_class.convert(quantity: 2, from_unit: nil, ingredient: ingredient(:mass, "g")))
          .to be_nil
      end
    end

    context "quand aucune conversion n'existe" do
      it "renonce entre des cuillères et une masse" do
        expect(described_class.convert(quantity: 2, from_unit: "càs", ingredient: ingredient(:mass, "g")))
          .to be_nil
      end

      # Le poids unitaire ne relie que masse et décompte : un volume reste hors
      # d'atteinte même quand il est renseigné.
      it "renonce entre un décompte et un volume, même avec un poids unitaire" do
        lait = ingredient(:volume, "ml", piece_weight_g: 1000)

        expect(described_class.convert(quantity: 1, from_unit: nil, ingredient: lait)).to be_nil
      end

      it "renonce sur une unité inconnue de la table" do
        expect(described_class.convert(quantity: 2, from_unit: "tranches", ingredient: ingredient(:mass, "g")))
          .to be_nil
      end
    end
  end

  describe ".compatible?" do
    it "reconnaît un pont ouvert par le poids unitaire" do
      expect(described_class.compatible?(from_unit: nil, ingredient: ingredient(:mass, "g", piece_weight_g: 40)))
        .to be(true)
    end

    it "refuse le même croisement sans poids unitaire" do
      expect(described_class.compatible?(from_unit: nil, ingredient: ingredient(:mass, "g")))
        .to be(false)
    end
  end
end
