# frozen_string_literal: true

require "rails_helper"

# UC2/UC7 — le remplacement 🔀 d'une carte tire dans le pool du MÊME moment,
# exclut la recette remplacée et les doublons du moment, et rend au nouveau
# repas la place exacte de l'ancien.
RSpec.describe Menus::ReplaceMealService do
  let(:menu) { create(:menu, diet: :omnivore, default_people: 4) }

  def publish(meal_types:, diet: :vegetarien)
    create(:recipe, :with_ingredient, meal_types: meal_types, diet: diet)
  end

  def add_meal(recipe, meal_type: "dinner", **attributes)
    create(:menu_recipe, { menu: menu, recipe: recipe, meal_type: meal_type,
                           number_of_people: 4 }.merge(attributes))
  end

  it "tire dans le pool du même moment et conserve la place du repas remplacé" do
    replaced = add_meal(publish(meal_types: %w[dinner]),
                        number_of_people: 6, position: 2, day_of_week: 1)
    dinner_candidate = publish(meal_types: %w[dinner])
    publish(meal_types: %w[breakfast]) # jamais tirée : mauvais moment

    new_meal = described_class.call(menu: menu, menu_recipe: replaced)

    expect(new_meal.recipe).to eq(dinner_candidate)
    expect(new_meal).to have_attributes(meal_type: "dinner", number_of_people: 6,
                                        position: 2, day_of_week: 1)
    expect(MenuRecipe.exists?(replaced.id)).to be(false)
  end

  it "écarte les recettes du même moment, pas celles présentes dans un autre moment" do
    both = publish(meal_types: %w[lunch dinner])
    add_meal(both, meal_type: "lunch")
    replaced = add_meal(publish(meal_types: %w[dinner]))

    new_meal = described_class.call(menu: menu, menu_recipe: replaced)

    # Seule candidate au dîner : `both` — présente en déjeuner, donc autorisée (UC7)
    expect(new_meal.recipe).to eq(both)
  end

  it "n'offre jamais deux fois la même recette dans un même moment" do
    add_meal(publish(meal_types: %w[dinner])) # dîner conservé
    replaced = add_meal(publish(meal_types: %w[dinner]))
    third = publish(meal_types: %w[dinner])

    new_meal = described_class.call(menu: menu, menu_recipe: replaced)

    # Le dîner conservé et la recette remplacée sont exclus : reste `third`
    expect(new_meal.recipe).to eq(third)
  end

  it "lève NoCandidatesError quand le pool du moment est épuisé" do
    replaced = add_meal(publish(meal_types: %w[dinner]))
    publish(meal_types: %w[breakfast]) # seul autre choix : mauvais moment

    expect { described_class.call(menu: menu, menu_recipe: replaced) }
      .to raise_error(Menus::NoCandidatesError)
  end

  it "remplace un repas sans moment dans tout le catalogue (brouillon d'avant les quotas)" do
    replaced = add_meal(publish(meal_types: %w[lunch]), meal_type: nil)
    candidate = publish(meal_types: %w[snack])

    new_meal = described_class.call(menu: menu, menu_recipe: replaced)

    expect(new_meal.recipe).to eq(candidate)
    expect(new_meal.meal_type).to be_nil
  end
end
