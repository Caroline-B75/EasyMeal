# frozen_string_literal: true

require "rails_helper"

# UC7 — vocabulaire partagé des moments du repas. Ces libellés alimentent les
# chips de la fiche recette, les steppers du formulaire de menu, les titres de
# sections du brouillon et les messages de manque : un seul point de traduction
# pour toute l'application.
RSpec.describe MealTypes do
  describe "MEAL_TYPES" do
    it "range les moments de la journée avant ceux qui n'y tiennent pas" do
      expect(described_class::MEAL_TYPES)
        .to eq(%w[breakfast lunch snack apero dinner starter salad dessert])
    end
  end

  # Filets de sécurité : ajouter un moment sans lui donner ses quatre libellés
  # le laisserait s'afficher en anglais humanisé (« Starter »), et sans icône il
  # tomberait sur le repli générique. Ces tests cassent dans les deux cas.
  describe "complétude du vocabulaire" do
    %w[meal_types meal_types_plural meal_types_compact meal_types_short].each do |scope|
      it "traduit exactement les moments dans #{scope}, ni plus ni moins" do
        expect(I18n.t(scope).keys.map(&:to_s)).to match_array(described_class::MEAL_TYPES)
      end
    end

    it "nomme pour chaque moment une icône réellement dessinée" do
      icons = described_class::MEAL_TYPES.map { |meal_type| described_class.icon(meal_type) }

      expect(icons).to all(be_in(ApplicationHelper::FEATHER_ICONS.keys))
      # « utensils » est le repli des moments inconnus : le voir ici signalerait
      # un moment oublié dans la table ICONS.
      expect(icons).not_to include("utensils")
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
