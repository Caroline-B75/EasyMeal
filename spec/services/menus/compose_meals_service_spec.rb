# frozen_string_literal: true

require "rails_helper"

# UC7, chapitre 3 — la re-génération : le moteur de composition remplace la
# composition d'un brouillon existant et mémorise la commande qu'il honore.
# (L'algorithme de tirage par quotas est couvert par les specs de
# Menus::GenerateService, qui délègue ici.)
RSpec.describe Menus::ComposeMealsService do
  let(:menu) { create(:menu, diet: :vegetarien, default_people: 2) }

  def publish(count = 1, meal_types:, diet: :vegetarien)
    create_list(:recipe, count, :with_ingredient, meal_types: meal_types, diet: diet)
  end

  it "remplace la composition existante et mémorise la nouvelle commande" do
    menu.update!(requested_meal_counts: { "dinner" => 1 })
    old_meal = create(:menu_recipe, menu: menu, recipe: publish(1, meal_types: %w[dinner]).first,
                                    meal_type: "dinner", number_of_people: 2)
    publish(2, meal_types: %w[lunch])

    described_class.call(menu: menu, meal_counts: MealCounts.new({ "lunch" => 2 }))

    expect(MenuRecipe.exists?(old_meal.id)).to be(false)
    meals = menu.menu_recipes.reload
    expect(meals.count).to eq(2)
    expect(meals.map(&:meal_type)).to all(eq("lunch"))
    expect(menu.requested_meal_counts).to eq({ "lunch" => 2 })
  end

  it "pioche dans le régime À JOUR du menu (changement de régime)" do
    vegan_dinner = publish(1, meal_types: %w[dinner], diet: :vegan).first
    publish(1, meal_types: %w[dinner], diet: :omnivore)
    menu.update!(diet: :vegan)

    described_class.call(menu: menu, meal_counts: MealCounts.new({ "dinner" => 2 }))

    expect(menu.menu_recipes.map(&:recipe)).to eq([ vegan_dinner ])
    expect(menu.missing_meal_counts).to eq({ "dinner" => 1 })
  end

  it "crée chaque repas pour le nombre de personnes du menu" do
    publish(1, meal_types: %w[dinner])

    described_class.call(menu: menu, meal_counts: MealCounts.new({ "dinner" => 1 }))

    expect(menu.menu_recipes.sole.number_of_people).to eq(2)
  end
end
