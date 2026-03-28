# frozen_string_literal: true

require "rails_helper"

RSpec.describe Quantities::HumanizeService do
  describe ".call" do
    # === Tests pour les masses (unit_group: mass) ===
    context "avec unit_group mass (grammes)" do
      it "retourne des grammes pour les petites quantités" do
        result = described_class.call(quantity: 250, unit_group: "mass")

        expect(result[:value]).to eq(250)
        expect(result[:unit]).to eq("g")
        expect(result[:display]).to eq("250 g")
      end

      it "convertit en kilogrammes pour 1000g ou plus" do
        result = described_class.call(quantity: 1500, unit_group: "mass")

        expect(result[:value]).to eq(1.5)
        expect(result[:unit]).to eq("kg")
        expect(result[:display]).to eq("1,5 kg")
      end

      it "affiche exactement 1 kg sans décimales" do
        result = described_class.call(quantity: 1000, unit_group: "mass")

        expect(result[:value]).to eq(1)
        expect(result[:unit]).to eq("kg")
        expect(result[:display]).to eq("1 kg")
      end

      it "arrondit les décimales à 2 chiffres" do
        result = described_class.call(quantity: 1555, unit_group: "mass")

        expect(result[:value]).to eq(1.56) # Arrondi
        expect(result[:display]).to eq("1,56 kg")
      end
    end

    # === Tests pour les volumes (unit_group: volume) ===
    context "avec unit_group volume (millilitres)" do
      it "retourne des millilitres pour les petites quantités" do
        result = described_class.call(quantity: 500, unit_group: "volume")

        expect(result[:value]).to eq(500)
        expect(result[:unit]).to eq("ml")
        expect(result[:display]).to eq("500 ml")
      end

      it "convertit en litres pour 1000ml ou plus" do
        result = described_class.call(quantity: 2000, unit_group: "volume")

        expect(result[:value]).to eq(2)
        expect(result[:unit]).to eq("L")
        expect(result[:display]).to eq("2 L")
      end

      it "affiche les décimales en litres avec virgule française" do
        result = described_class.call(quantity: 1250, unit_group: "volume")

        expect(result[:value]).to eq(1.25)
        expect(result[:display]).to eq("1,25 L")
      end
    end

    # === Tests pour les cuillères (unit_group: spoon) ===
    context "avec unit_group spoon (càc)" do
      it "retourne des cuillères à café pour les petites quantités" do
        result = described_class.call(quantity: 2, unit_group: "spoon")

        expect(result[:value]).to eq(2)
        expect(result[:unit]).to eq("càc")
        expect(result[:display]).to eq("2 càc")
      end

      it "convertit 3 càc en 1 càs" do
        result = described_class.call(quantity: 3, unit_group: "spoon")

        expect(result[:value]).to eq(1)
        expect(result[:unit]).to eq("càs")
        expect(result[:display]).to eq("1 càs")
      end

      it "convertit 6 càc en 2 càs" do
        result = described_class.call(quantity: 6, unit_group: "spoon")

        expect(result[:value]).to eq(2)
        expect(result[:unit]).to eq("càs")
        expect(result[:display]).to eq("2 càs")
      end

      it "affiche les càs avec fractions si nécessaire" do
        result = described_class.call(quantity: 4.5, unit_group: "spoon")

        expect(result[:value]).to eq(1.5)
        expect(result[:unit]).to eq("càs")
        expect(result[:display]).to eq("1,5 càs")
      end

      it "convertit 0.25 càc en pincée" do
        result = described_class.call(quantity: 0.25, unit_group: "spoon")

        expect(result[:value]).to eq(1)
        expect(result[:unit]).to eq("pincée")
        expect(result[:display]).to eq("1 pincée")
      end

      it "convertit 0.5 càc en 2 pincées" do
        result = described_class.call(quantity: 0.5, unit_group: "spoon")

        expect(result[:value]).to eq(2)
        expect(result[:unit]).to eq("pincées")
        expect(result[:display]).to eq("2 pincées")
      end
    end

    # === Tests pour le comptage (unit_group: count) ===
    context "avec unit_group count (pièces)" do
      it "retourne le nombre entier sans unité" do
        result = described_class.call(quantity: 3, unit_group: "count")

        expect(result[:value]).to eq(3)
        expect(result[:unit]).to eq("")
        expect(result[:display]).to eq("3")
      end

      it "arrondit les décimales pour les comptages" do
        result = described_class.call(quantity: 2.7, unit_group: "count")

        expect(result[:value]).to eq(3)
        expect(result[:display]).to eq("3")
      end

      it "affiche les demi-unités" do
        result = described_class.call(quantity: 1.5, unit_group: "count")

        expect(result[:value]).to eq(1.5)
        expect(result[:display]).to eq("1,5")
      end
    end

    # === Tests pour les cas limites ===
    context "cas limites" do
      it "gère une quantité nulle" do
        result = described_class.call(quantity: 0, unit_group: "mass")

        expect(result[:value]).to eq(0)
        expect(result[:display]).to eq("0 g")
      end

      it "gère un unit_group invalide en retournant la quantité brute" do
        result = described_class.call(quantity: 5, unit_group: "unknown")

        expect(result[:value]).to eq(5)
        expect(result[:display]).to eq("5")
      end

      it "gère les très petites quantités de masse" do
        result = described_class.call(quantity: 0.5, unit_group: "mass")

        expect(result[:value]).to eq(0.5)
        expect(result[:display]).to eq("0,5 g")
      end
    end
  end
end
