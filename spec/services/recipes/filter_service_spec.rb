# frozen_string_literal: true

require "rails_helper"

# UC7 (Prompt 3) : le catalogue filtre par moment du repas.
# Le scope for_meal_type est déjà testé à fond dans recipe_spec.rb — ici on
# vérifie uniquement que FilterService le déclenche correctement depuis les
# params (seul, absent, et combiné avec un autre filtre existant).
RSpec.describe Recipes::FilterService do
  let!(:breakfast_recipe) { create(:recipe, :with_ingredient, diet: :vegetarien, meal_types: %w[breakfast]) }
  let!(:dinner_recipe)    { create(:recipe, :with_ingredient, diet: :omnivore,   meal_types: %w[dinner]) }

  describe "filtre meal_type" do
    it "ne retient que les recettes taguées du moment demandé" do
      result = described_class.call(Recipe.all, ActionController::Parameters.new(meal_type: "breakfast"))

      expect(result).to contain_exactly(breakfast_recipe)
    end

    it "ne filtre pas quand le paramètre est absent" do
      result = described_class.call(Recipe.all, ActionController::Parameters.new)

      expect(result).to contain_exactly(breakfast_recipe, dinner_recipe)
    end

    it "se combine avec le filtre régime" do
      vegan_dinner = create(:recipe, :with_ingredient, diet: :vegan, meal_types: %w[dinner])

      result = described_class.call(Recipe.all, ActionController::Parameters.new(meal_type: "dinner", diet: "vegan"))

      expect(result).to contain_exactly(vegan_dinner)
    end
  end
end
