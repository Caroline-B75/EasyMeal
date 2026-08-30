# frozen_string_literal: true

require "rails_helper"

RSpec.describe PieceCounting do
  def ingredient(unit_group: "mass", **attributes)
    build(:ingredient,
          unit_group: unit_group,
          base_unit:  Ingredient::BASE_UNITS.fetch(unit_group),
          **attributes)
  end

  describe "#piece_measure" do
    it "lit le poids d'une pièce quand il est renseigné" do
      expect(ingredient(piece_weight_g: 300).piece_measure).to eq([ 300.0, "mass" ])
    end

    it "lit le volume d'une pièce sur ce qui se verse" do
      lait = ingredient(unit_group: "volume", piece_volume_ml: 1000)

      expect(lait.piece_measure).to eq([ 1000.0, "volume" ])
    end

    it "rend nil quand rien ne dit ce que contient une pièce" do
      expect(ingredient.piece_measure).to be_nil
    end
  end

  describe "#unit_select_options" do
    # Ce que le sélecteur proposait avant la pièce, et propose toujours.
    it "propose les unités du groupe" do
      expect(ingredient.unit_select_options).to eq([ [ "g", "g" ], [ "kg", "kg" ] ])
    end

    it "ajoute la pièce à ce qui se pèse, sous son nom" do
      aubergine = ingredient(piece_weight_g: 300, piece_label: "pièce")

      expect(aubergine.unit_select_options).to eq([ [ "g", "g" ], [ "kg", "kg" ], [ "pièce", "piece" ] ])
    end

    it "donne son vrai nom à la pièce" do
      chocolat = ingredient(piece_weight_g: 200, piece_label: "tablette")

      expect(chocolat.unit_select_options).to include([ "tablette", "piece" ])
    end

    # Le sens inverse : « 200 g d'oignon » se saisit comme l'import IA sait déjà
    # le lire, sans quoi deux ingrédients voisins d'une recette se saisiraient
    # différemment sans raison visible.
    it "ajoute la mesure à ce qui se compte" do
      oignon = ingredient(unit_group: "count", piece_weight_g: 110, piece_label: "pièce")

      expect(oignon.unit_select_options).to eq([ [ "pièce", "piece" ], [ "g", "g" ], [ "kg", "kg" ] ])
    end

    # Les unités du volume au complet, cuillères comprises : ce sont celles que
    # Units offre déjà aux liquides, et la pièce ne fait que les rendre
    # accessibles à un ingrédient qui se compte.
    it "ajoute les unités de volume à ce qui se compte et se verse" do
      brique = ingredient(unit_group: "count", piece_volume_ml: 1000, piece_label: "brique")

      expect(brique.unit_select_options.map(&:last)).to eq(%w[piece ml cl dl l cac cas])
    end

    it "n'ajoute rien à un ingrédient compté sans mesure connue" do
      oeuf = ingredient(unit_group: "count", piece_label: "œuf")

      expect(oeuf.unit_select_options).to eq([ [ "œuf", "piece" ] ])
    end

    it "laisse le sélecteur inchangé quand l'ingrédient ne s'achète pas à la pièce" do
      jambon = ingredient(piece_weight_g: 40)

      expect(jambon.unit_select_options).to eq([ [ "g", "g" ], [ "kg", "kg" ] ])
    end
  end
end
