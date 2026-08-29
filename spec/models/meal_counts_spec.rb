# frozen_string_literal: true

require "rails_helper"

# UC7 — objet-valeur de la répartition des repas par moment.
# C'est lui qui protège tout le reste du code : ce qui entre est normalisé,
# ce qui sort est toujours exploitable.
RSpec.describe MealCounts do
  describe ".from_hash" do
    it "ne retient que les moments connus, en entiers" do
      counts = described_class.from_hash({ "breakfast" => "7", "brunch" => "3", "dinner" => 2 })

      expect(counts.to_h).to eq({ "breakfast" => 7, "dinner" => 2 })
    end

    it "accepte les clés symbole et ignore les quotas nuls ou absurdes" do
      counts = described_class.from_hash({ lunch: 2, snack: 0, apero: -4, dinner: "n'importe quoi" })

      expect(counts.to_h).to eq({ "lunch" => 2 })
    end

    it "borne les quotas au maximum d'un stepper" do
      counts = described_class.from_hash({ "dinner" => 99 })

      expect(counts[:dinner]).to eq(described_class::MAX)
    end

    it "accepte une source vide" do
      expect(described_class.from_hash(nil).to_h).to eq({})
    end

    it "relit la forme mémorisée telle qu'elle a été écrite" do
      stored = described_class.from_hash({ "breakfast" => 7, "same_breakfast" => "1" }).to_h

      expect(described_class.from_hash(stored).same_breakfast?).to be(true)
    end
  end

  describe ".from_menu_recipes" do
    it "compte les repas par moment" do
      meals = [
        MenuRecipe.new(meal_type: "dinner"),
        MenuRecipe.new(meal_type: "dinner"),
        MenuRecipe.new(meal_type: "breakfast")
      ]

      expect(described_class.from_menu_recipes(meals).to_h).to eq({ "breakfast" => 1, "dinner" => 2 })
    end

    it "range les repas sans moment en déjeuner, pour préserver le total" do
      counts = described_class.from_menu_recipes([ MenuRecipe.new, MenuRecipe.new(meal_type: "lunch") ])

      expect(counts.total).to eq(2)
      expect(counts[:lunch]).to eq(2)
    end
  end

  describe "#total et #any?" do
    it "additionne les quotas commandés" do
      counts = described_class.new({ "breakfast" => 7, "lunch" => 2, "dinner" => 7 })

      expect(counts.total).to eq(16)
      expect(counts.any?).to be(true)
    end

    it "considère une semaine vide comme rien à générer" do
      expect(described_class.new.any?).to be(false)
      expect(described_class.new.total).to eq(0)
    end
  end

  describe "#same_breakfast?" do
    it "retient l'option à partir de deux petits-déjeuners" do
      counts = described_class.new({ "breakfast" => 2 }, same_breakfast: true)

      expect(counts.same_breakfast?).to be(true)
      expect(counts.to_h).to include({ "same_breakfast" => true })
    end

    it "ignore l'option en dessous du seuil : il n'y a rien à répéter" do
      counts = described_class.new({ "breakfast" => 1 }, same_breakfast: true)

      expect(counts.same_breakfast?).to be(false)
      expect(counts.to_h).not_to have_key("same_breakfast")
    end
  end

  describe "#[]" do
    it "renvoie 0 pour un moment non commandé" do
      expect(described_class.new({ "dinner" => 3 })[:breakfast]).to eq(0)
    end
  end
end
