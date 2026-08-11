# frozen_string_literal: true

require "rails_helper"

RSpec.describe Ingredient, type: :model do
  describe "BASE_UNITS" do
    # Filet de sécurité : ce test casse si on ajoute un groupe d'unités à l'enum
    # sans lui donner son unité de base (ou l'inverse).
    it "définit exactement une unité de base par groupe d'unités de l'enum" do
      expect(Ingredient::BASE_UNITS.keys).to match_array(Ingredient.unit_groups.keys)
    end
  end

  describe "validation base_unit_matches_unit_group" do
    Ingredient::BASE_UNITS.each do |unit_group, base_unit|
      context "pour le groupe #{unit_group}" do
        it "accepte l'unité de base « #{base_unit} »" do
          ingredient = build(:ingredient, unit_group: unit_group, base_unit: base_unit)

          expect(ingredient).to be_valid
        end

        it "refuse une unité qui n'est pas « #{base_unit} »" do
          ingredient = build(:ingredient, unit_group: unit_group, base_unit: "litron")

          expect(ingredient).not_to be_valid
          expect(ingredient.errors[:base_unit])
            .to include("doit être #{base_unit} pour le groupe #{unit_group}")
        end
      end
    end
  end
end
