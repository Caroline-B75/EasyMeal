# frozen_string_literal: true

require "rails_helper"

# UC7 — les steppers de répartition du panneau de réglages du brouillon :
# « + » pose un repas de plus du moment à la suite de la grille, « − » retire le
# dernier, et la commande du menu (requested_meal_counts) suit le geste pour ce
# moment-là seulement.
RSpec.describe Menus::AdjustMealCountService do
  let(:menu) { create(:menu, diet: :omnivore, default_people: 4) }

  def publish(meal_types:, **attributes)
    create(:recipe, :with_ingredient, meal_types: meal_types, **attributes)
  end

  def add_meal(recipe, meal_type: "dinner", **attributes)
    create(:menu_recipe, { menu: menu, recipe: recipe, meal_type: meal_type,
                           number_of_people: 4, position: menu.menu_recipes.count }.merge(attributes))
  end

  describe "ajout d'un repas (delta positif)" do
    it "tire une recette du moment demandé et la pose à la suite de la grille" do
      add_meal(publish(meal_types: %w[dinner]), position: 0)
      candidate = publish(meal_types: %w[snack])
      publish(meal_types: %w[breakfast]) # jamais tirée : mauvais moment

      described_class.call(menu: menu, meal_type: "snack", delta: 1)

      snack = menu.menu_recipes.for_meal("snack").sole
      expect(snack).to have_attributes(recipe: candidate, position: 1, number_of_people: 4)
    end

    it "aligne la commande du moment ajouté, sans toucher aux autres" do
      menu.update!(requested_meal_counts: { "breakfast" => 3, "dinner" => 5 })
      add_meal(publish(meal_types: %w[dinner]))
      publish(meal_types: %w[dinner])

      described_class.call(menu: menu, meal_type: "dinner", delta: 1)

      # Deux dîners au menu désormais : la commande du dîner les rejoint, celle
      # du petit-déjeuner ne bouge pas.
      expect(menu.reload.requested_meal_counts).to eq({ "breakfast" => 3, "dinner" => 2 })
    end

    it "répète la même recette quand le menu a été commandé « même petit-déjeuner »" do
      menu.update!(requested_meal_counts: { "breakfast" => 2, "same_breakfast" => true })
      brioche = publish(meal_types: %w[breakfast])
      add_meal(brioche, meal_type: "breakfast")
      publish(meal_types: %w[breakfast]) # candidate ignorée : le matin ne change pas

      described_class.call(menu: menu, meal_type: "breakfast", delta: 1)

      expect(menu.menu_recipes.for_meal("breakfast").map(&:recipe)).to eq([ brioche, brioche ])
    end

    it "lève NoCandidatesError en nommant le moment quand le pool est épuisé" do
      add_meal(publish(meal_types: %w[dinner]))

      expect { described_class.call(menu: menu, meal_type: "dinner", delta: 1) }
        .to raise_error(Menus::NoCandidatesError, /recette de dîner/)
    end

    it "ne dépasse jamais le plafond d'un quota" do
      MealCounts::MAX.times { add_meal(publish(meal_types: %w[dinner])) }
      publish(meal_types: %w[dinner])

      expect { described_class.call(menu: menu, meal_type: "dinner", delta: 1) }
        .not_to change { menu.menu_recipes.count }
    end
  end

  describe "retrait d'un repas (delta négatif)" do
    it "retire le dernier repas du moment dans la grille et laisse les autres moments" do
      lunch = add_meal(publish(meal_types: %w[lunch]), meal_type: "lunch", position: 0)
      kept  = add_meal(publish(meal_types: %w[dinner]), position: 1)
      last  = add_meal(publish(meal_types: %w[dinner]), position: 2)

      described_class.call(menu: menu, meal_type: "dinner", delta: -1)

      expect(menu.menu_recipes.by_position).to eq([ lunch, kept ])
      expect(MenuRecipe.exists?(last.id)).to be(false)
    end

    it "efface le manque né de la commande initiale : c'est elle qu'on vient de revoir" do
      menu.update!(requested_meal_counts: { "dinner" => 5 })
      add_meal(publish(meal_types: %w[dinner]))
      add_meal(publish(meal_types: %w[dinner]))

      described_class.call(menu: menu, meal_type: "dinner", delta: -1)

      expect(menu.reload.requested_meal_counts).to eq({ "dinner" => 1 })
      expect(menu.missing_meal_counts).to be_empty
    end

    it "retire aussi un repas sans moment, rangé au déjeuner comme partout ailleurs" do
      untyped = add_meal(publish(meal_types: %w[lunch]), meal_type: nil)

      described_class.call(menu: menu, meal_type: "lunch", delta: -1)

      expect(MenuRecipe.exists?(untyped.id)).to be(false)
    end

    it "ne fait rien sur un moment déjà vide" do
      add_meal(publish(meal_types: %w[dinner]))

      expect { described_class.call(menu: menu, meal_type: "apero", delta: -1) }
        .not_to change { menu.menu_recipes.count }
    end
  end
end
