# frozen_string_literal: true

require "rails_helper"

# UC7, chapitre 3 — le moteur de génération honore la commande par moment :
# un pool par moment (recettes publiées + compatibles régime + taguées),
# priorité saison à l'intérieur de chaque quota, répétition permise entre
# moments mais pas dans un même moment, remplissage partiel sans erreur,
# commande mémorisée sur le menu.
RSpec.describe Menus::GenerateService do
  let(:user) { create(:user) }

  # Lance une génération avec une commande donnée (clés string).
  def generate(counts, same_breakfast: false, diet: :omnivore)
    described_class.call(
      user:           user,
      diet:           diet,
      default_people: 3,
      meal_counts:    MealCounts.new(counts, same_breakfast: same_breakfast)
    )
  end

  # Publie des recettes prêtes au tirage (ingrédient + moments), végétariennes
  # par défaut : compatibles avec un menu omnivore comme végétarien.
  def publish(count = 1, meal_types:, diet: :vegetarien, seasonal: false)
    create_list(:recipe, count, (seasonal ? :seasonal : :with_ingredient),
                meal_types: meal_types, diet: diet)
  end

  describe "quotas par moment" do
    it "honore chaque quota et tague chaque repas de son moment, dans l'ordre de la journée" do
      publish(3, meal_types: %w[breakfast])
      publish(4, meal_types: %w[dinner])

      menu = generate({ "breakfast" => 2, "dinner" => 3 })

      expect(menu).to be_persisted
      meals = menu.menu_recipes.by_position
      expect(meals.map(&:meal_type)).to eq(%w[breakfast breakfast dinner dinner dinner])
      expect(meals.map(&:position)).to eq([ 0, 1, 2, 3, 4 ])
      expect(meals.map(&:number_of_people)).to all(eq(3))
    end

    it "mémorise la commande sur le menu, pour les manques et la re-génération" do
      publish(2, meal_types: %w[dinner])

      menu = generate({ "dinner" => 2 })

      expect(menu.requested_meal_counts).to eq({ "dinner" => 2 })
    end

    it "ne pioche que des recettes publiées, compatibles régime et taguées du moment" do
      compatible = publish(1, meal_types: %w[dinner], diet: :vegan).first
      publish(1, meal_types: %w[dinner], diet: :omnivore)                   # régime incompatible
      publish(1, meal_types: %w[breakfast], diet: :vegan)                   # mauvais moment
      create(:recipe, status: :draft, meal_types: %w[dinner], diet: :vegan) # non publiée

      menu = generate({ "dinner" => 3 }, diet: :vegetarien)

      expect(menu.menu_recipes.map(&:recipe)).to eq([ compatible ])
    end
  end

  describe "priorité saison à l'intérieur de chaque quota" do
    it "sert d'abord les recettes de saison de chaque pool" do
      seasonal_dinners = publish(2, meal_types: %w[dinner], seasonal: true)
      publish(3, meal_types: %w[dinner])
      seasonal_breakfast = publish(1, meal_types: %w[breakfast], seasonal: true).first
      publish(2, meal_types: %w[breakfast])

      menu = generate({ "breakfast" => 1, "dinner" => 2 })

      expect(menu.menu_recipes.for_meal("dinner").map(&:recipe)).to match_array(seasonal_dinners)
      expect(menu.menu_recipes.for_meal("breakfast").map(&:recipe)).to eq([ seasonal_breakfast ])
    end

    it "complète avec le hors-saison quand le pool de saison s'épuise" do
      seasonal = publish(1, meal_types: %w[dinner], seasonal: true).first
      publish(4, meal_types: %w[dinner])

      menu = generate({ "dinner" => 3 })

      picked = menu.menu_recipes.map(&:recipe)
      expect(picked.size).to eq(3)
      expect(picked).to include(seasonal)
    end
  end

  describe "répétition permise (UC7)" do
    it "autorise la même recette dans deux moments, jamais deux fois dans le même" do
      quiche = publish(1, meal_types: %w[lunch dinner]).first

      menu = generate({ "lunch" => 2, "dinner" => 2 })

      expect(menu.menu_recipes.for_meal("lunch").map(&:recipe)).to eq([ quiche ])
      expect(menu.menu_recipes.for_meal("dinner").map(&:recipe)).to eq([ quiche ])
    end

    it "place N cartes distinctes de la même recette avec l'option « même petit-déjeuner »" do
      publish(3, meal_types: %w[breakfast])

      menu = generate({ "breakfast" => 4 }, same_breakfast: true)

      breakfasts = menu.menu_recipes.for_meal("breakfast")
      expect(breakfasts.count).to eq(4)
      expect(breakfasts.map(&:recipe_id).uniq.size).to eq(1)
      expect(menu.requested_meal_counts).to include("same_breakfast" => true)
    end
  end

  describe "remplissage partiel — jamais d'erreur" do
    it "remplit ce qu'il peut et laisse le menu exposer les manques" do
      publish(1, meal_types: %w[breakfast])

      menu = nil
      expect { menu = generate({ "breakfast" => 2, "apero" => 1, "dinner" => 1 }) }
        .not_to raise_error

      expect(menu.menu_recipes.count).to eq(1)
      expect(menu.missing_meal_counts).to eq({ "breakfast" => 1, "apero" => 1, "dinner" => 1 })
    end

    it "crée un menu sans repas quand le catalogue est vide" do
      menu = generate({ "dinner" => 3 })

      expect(menu).to be_persisted
      expect(menu.menu_recipes).to be_empty
      expect(menu.missing_meal_counts).to eq({ "dinner" => 3 })
    end
  end

  it "remplace l'éventuel brouillon existant de l'utilisatrice" do
    publish(1, meal_types: %w[dinner])
    previous_draft = create(:menu, user: user, status: :draft)

    menu = generate({ "dinner" => 1 })

    expect(Menu.exists?(previous_draft.id)).to be(false)
    expect(user.menus.status_draft.sole).to eq(menu)
  end
end
