# frozen_string_literal: true

require "rails_helper"

RSpec.describe IngredientMatcherService do
  describe ".match" do
    it "trouve l'ingrédient par son nom, quelle que soit la casse" do
      thym = create(:ingredient, name: "Thym frais")

      expect(described_class.match("THYM FRAIS")).to eq(exact: thym, fuzzy: [])
    end

    it "trouve l'ingrédient par un alias appris lors d'un import précédent" do
      thym = create(:ingredient, name: "Thym frais", aliases: [ "brin de thym" ])

      expect(described_class.match("Brin de thym")).to eq(exact: thym, fuzzy: [])
    end

    it "préfère l'ingrédient qui porte le nom à celui qui l'a appris en alias" do
      create(:ingredient, name: "Thym séché", aliases: [ "thym" ])
      thym = create(:ingredient, name: "Thym")

      expect(described_class.match("thym")[:exact]).to eq(thym)
    end

    # Le nom complet prime : un ingrédient réellement nommé « brin de thym »
    # ne doit pas être supplanté par la forme réduite.
    it "préfère le nom complet à sa forme réduite" do
      brin = create(:ingredient, name: "Brin de thym")
      create(:ingredient, name: "Thym")

      expect(described_class.match("brin de thym")[:exact]).to eq(brin)
    end

    it "retire le quantificateur pour retrouver l'ingrédient nommé simplement" do
      thym = create(:ingredient, name: "Thym")

      expect(described_class.match("2 brins de thym")[:exact]).to eq(thym)
    end

    it "retire aussi un quantificateur accentué" do
      sel = create(:ingredient, name: "Sel")

      expect(described_class.match("pincée de sel")[:exact]).to eq(sel)
    end

    # Le cas qui motivait tout : « brin de thym » et « Thym frais » sont trop
    # éloignés pour la similarité globale (0,26 < 0,3) mais le sont beaucoup
    # moins une fois le quantificateur retiré.
    it "suggère l'ingrédient dont le nom contient le terme réduit" do
      thym = create(:ingredient, name: "Thym frais")

      result = described_class.match("Brin de thym")

      expect(result[:exact]).to be_nil
      expect(result[:fuzzy]).to include(thym)
    end

    it "suggère l'ingrédient malgré une faute de frappe" do
      tomate = create(:ingredient, name: "Tomate")

      expect(described_class.match("tomatte")[:fuzzy]).to include(tomate)
    end

    it "ne suggère rien quand aucun ingrédient ne ressemble" do
      create(:ingredient, name: "Persil")

      expect(described_class.match("boulgour")).to eq(exact: nil, fuzzy: [])
    end

    it "ne cherche rien pour un nom vide" do
      expect(described_class.match("  ")).to eq(exact: nil, fuzzy: [])
    end
  end

  describe ".strip_quantifier" do
    it "retire le quantificateur de tête" do
      expect(described_class.strip_quantifier("gousse d'ail")).to eq("ail")
      expect(described_class.strip_quantifier("quelques feuilles de basilic")).to eq("basilic")
    end

    it "laisse intact un nom qui n'en porte pas" do
      expect(described_class.strip_quantifier("huile d'olive")).to eq("huile d'olive")
      # « noix de coco » est un ingrédient, pas une noix de quelque chose
      expect(described_class.strip_quantifier("noix de coco")).to eq("noix de coco")
    end

    it "garde le nom d'origine plutôt que de le vider" do
      expect(described_class.strip_quantifier("brin de")).to eq("brin de")
    end
  end
end
