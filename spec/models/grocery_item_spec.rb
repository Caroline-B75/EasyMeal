# frozen_string_literal: true

require "rails_helper"

RSpec.describe GroceryItem, type: :model do
  describe "effacement du badge (previous_quantity_base) au cochage" do
    it "efface previous_quantity_base quand l'article passe à coché" do
      item = create(:grocery_item, checked: false, previous_quantity_base: 50)

      item.update!(checked: true)

      expect(item.reload.previous_quantity_base).to be_nil
    end

    it "conserve previous_quantity_base tant que l'article reste décoché" do
      item = create(:grocery_item, checked: false, previous_quantity_base: 50)

      item.update!(quantity_base: 30)

      expect(item.reload.previous_quantity_base).to eq(50)
    end
  end

  describe "#previous_quantity_display" do
    it "humanise l'ancienne quantité comme quantity_display" do
      item = build(:grocery_item, unit_group: :mass, base_unit: "g", previous_quantity_base: 1500)

      expect(item.previous_quantity_display).to eq("1,5 kg")
    end
  end

  describe "affichage d'une quantité minuscule (jamais « 0 »)" do
    it "montre la valeur exacte plutôt que 0 pour une petite masse" do
      item = build(:grocery_item, unit_group: :mass, base_unit: "g", quantity_base: 0.003)

      expect(item.quantity_display).to eq("0,003 g")
    end

    it "montre la valeur exacte plutôt que 0 pour un petit comptage" do
      item = build(:grocery_item, unit_group: :count, base_unit: "piece", quantity_base: 0.03)

      expect(item.quantity_display).to eq("0,03")
    end
  end
end
