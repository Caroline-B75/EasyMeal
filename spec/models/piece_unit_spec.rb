# frozen_string_literal: true

require "rails_helper"

RSpec.describe PieceUnit do
  # De vrais ingrédients plutôt qu'un double : PieceUnit lit ce que le concern
  # PieceCounting expose (piece_measure), et c'est ce contrat-là qu'on veut voir
  # tenir. Non persistés — rien ici ne touche la base.
  def porteur(unit_group: "mass", **attributes)
    build(:ingredient,
          unit_group: unit_group,
          base_unit:  Ingredient::BASE_UNITS.fetch(unit_group),
          **attributes)
  end

  # L'aubergine du catalogue : se pèse, 300 g la pièce.
  let(:aubergine) { described_class.for(porteur(piece_label: "pièce", piece_weight_g: 300)) }
  # Le lait : se verse, 1 L la brique.
  let(:lait) do
    described_class.for(porteur(piece_label: "brique", piece_volume_ml: 1000, unit_group: "volume"))
  end
  # Le yaourt : se compte déjà, et une pièce pèse 125 g.
  let(:yaourt) do
    described_class.for(porteur(piece_label: "pot", piece_weight_g: 125, unit_group: "count"))
  end

  describe ".for" do
    it "rend nil sans nom de pièce — l'ingrédient se pèse" do
      expect(described_class.for(porteur(piece_weight_g: 300))).to be_nil
    end

    it "se construit dès qu'un nom de pièce est présent" do
      expect(aubergine).to be_a(described_class)
    end
  end

  describe "#count_for" do
    it "divise la mesure par le contenu d'une pièce" do
      expect(aubergine.count_for(600)).to eq(2)
    end

    it "arrondit au supérieur : on n'achète pas deux courgettes et demie" do
      expect(aubergine.count_for(750)).to eq(3)
    end

    it "compte une pièce dès qu'il en faut une fraction" do
      expect(lait.count_for(3)).to eq(1)
    end

    it "prend la quantité telle quelle quand l'ingrédient se compte déjà" do
      expect(yaourt.count_for(4)).to eq(4)
    end

    it "arrondit aussi ce qui se compte : 1,8 oignon en fait 2" do
      expect(yaourt.count_for(1.8)).to eq(2)
    end

    it "ignore le bruit du flottant sous le millième" do
      expect(aubergine.count_for(899.9999)).to eq(3)
    end

    it "rend nil quand rien ne permet de compter" do
      orphelin = described_class.for(porteur(piece_label: "pièce"))

      expect(orphelin.count_for(600)).to be_nil
    end
  end

  describe "#exact?" do
    it "est vrai quand la quantité tombe sur un nombre entier de pièces" do
      expect(aubergine.exact?(600)).to be true
    end

    it "est faux dès qu'on achète plus que nécessaire" do
      expect(aubergine.exact?(750)).to be false
    end

    it "est vrai pour un compte entier d'un ingrédient déjà compté" do
      expect(yaourt.exact?(4)).to be true
    end
  end

  describe "#label_for" do
    it "laisse le singulier à une pièce" do
      expect(aubergine.label_for(1)).to eq("pièce")
    end

    it "ajoute un « s » au-delà" do
      expect(aubergine.label_for(3)).to eq("pièces")
    end

    it "préfère le pluriel écrit quand le français refuse le « s »" do
      maquereau = described_class.for(
        porteur(piece_label: "maquereau", piece_label_plural: "maquereaux", piece_weight_g: 250)
      )

      expect(maquereau.label_for(2)).to eq("maquereaux")
    end

    it "respecte un pluriel invariable" do
      gambas = described_class.for(
        porteur(piece_label: "gambas", piece_label_plural: "gambas", piece_weight_g: 30)
      )

      expect(gambas.label_for(12)).to eq("gambas")
    end
  end

  describe "#sentence_for" do
    it "met la mesure entre parenthèses quand elle tombe juste" do
      expect(aubergine.sentence_for(600)).to eq("2 pièces (600 g)")
    end

    it "annonce le surplus par « pour » quand on achète plus que nécessaire" do
      expect(aubergine.sentence_for(750)).to eq("3 pièces pour 750 g")
    end

    it "dit le peu qu'on utilise d'une brique entière" do
      expect(lait.sentence_for(3)).to eq("1 brique pour 3 ml")
    end

    it "ne s'encombre pas d'un surplus quand la brique est bue en entier" do
      expect(lait.sentence_for(1000)).to eq("1 brique (1 L)")
    end

    it "déduit la mesure d'un ingrédient qui se compte" do
      expect(yaourt.sentence_for(4)).to eq("4 pots (500 g)")
    end

    it "se passe de mesure quand aucune n'est connue" do
      oeuf = described_class.for(porteur(piece_label: "œuf", unit_group: "count"))

      expect(oeuf.sentence_for(6)).to eq("6 œufs")
    end

    it "rend nil pour une quantité nulle" do
      expect(aubergine.sentence_for(0)).to be_nil
    end
  end
end
