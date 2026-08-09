# frozen_string_literal: true

require "rails_helper"

# UC7 — vocabulaire partagé des moments du repas. Ces libellés alimentent les
# chips de la fiche recette, les steppers du formulaire de menu, les titres de
# sections du brouillon et les messages de manque : un seul point de traduction
# pour toute l'application.
RSpec.describe MealTypes do
  describe "MEAL_TYPES" do
    it "suit le déroulé de la journée" do
      expect(described_class::MEAL_TYPES).to eq(%w[breakfast lunch snack apero dinner])
    end
  end

  describe ".label / .plural_label" do
    it "traduit le moment au singulier et au pluriel" do
      expect(described_class.label("apero")).to eq("Apéro")
      expect(described_class.plural_label("breakfast")).to eq("Petits-déjeuners")
    end

    it "renvoie nil quand aucun moment n'est fourni" do
      expect(described_class.label(nil)).to be_nil
      expect(described_class.plural_label("")).to be_nil
    end
  end

  describe ".short_label" do
    it "accorde la forme compacte de la barre de résumé" do
      expect(described_class.short_label("breakfast", 1)).to eq("petit-déj")
      expect(described_class.short_label("breakfast", 7)).to eq("petits-déjs")
    end
  end

  describe ".inline_label" do
    it "renvoie la forme minuscule accordée qui s'insère dans une phrase" do
      expect(described_class.inline_label("snack", 1)).to eq("goûter")
      expect(described_class.inline_label("snack", 3)).to eq("goûters")
    end

    it "part du pluriel, registre le plus courant" do
      expect(described_class.inline_label("dinner")).to eq("dîners")
    end
  end
end
