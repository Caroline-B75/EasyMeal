# frozen_string_literal: true

require "rails_helper"

RSpec.describe Menu, type: :model do
  let(:user) { create(:user) }

  describe "validations" do
    it "n'autorise qu'un seul brouillon par utilisateur" do
      create(:menu, user: user, status: :draft)

      duplicate = build(:menu, user: user, status: :draft)

      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:user_id]).to include("a déjà un menu à valider")
    end
  end

  describe "#revert_to_draft!" do
    it "repasse un menu actif en brouillon" do
      menu = create(:menu, user: user, status: :active)

      menu.revert_to_draft!

      expect(menu.reload).to be_status_draft
    end

    it "remplace le brouillon existant" do
      existing_draft = create(:menu, user: user, status: :draft)
      menu = create(:menu, user: user, status: :active)

      menu.revert_to_draft!

      expect(menu.reload).to be_status_draft
      expect(Menu.exists?(existing_draft.id)).to be false
      expect(user.menus.status_draft.count).to eq(1)
    end

    it "conserve les grocery_items tels quels (coches comprises)" do
      menu = create(:menu, user: user, status: :active)
      item = create(:grocery_item, menu: menu, checked: true)

      menu.revert_to_draft!

      expect(GroceryItem.exists?(item.id)).to be true
      expect(item.reload.checked).to be true
    end

    it "lève une erreur métier depuis un brouillon" do
      menu = create(:menu, user: user, status: :draft)

      expect { menu.revert_to_draft! }.to raise_error(Menu::InvalidTransitionError, /actif/)
    end

    it "lève une erreur métier depuis un menu archivé" do
      menu = create(:menu, user: user, status: :archived)

      expect { menu.revert_to_draft! }.to raise_error(Menu::InvalidTransitionError, /actif/)
    end
  end

  # UC7, chapitre 3 — « Il manque 3 petits-déjeuners » : la commande mémorisée
  # comparée aux repas réellement présents.
  describe "#missing_meal_counts" do
    let(:menu) { create(:menu, user: user) }
    let(:recipe) { create(:recipe, :with_ingredient) }

    def add_meal(meal_type)
      create(:menu_recipe, menu: menu, recipe: recipe, meal_type: meal_type)
    end

    it "compare la commande mémorisée aux repas présents, dans l'ordre de la journée" do
      menu.update!(requested_meal_counts: { "apero" => 1, "dinner" => 2, "breakfast" => 3 })
      add_meal("breakfast")
      2.times { add_meal("dinner") }

      expect(menu.missing_meal_counts).to eq({ "breakfast" => 2, "apero" => 1 })
      expect(menu.missing_meal_counts.keys).to eq(%w[breakfast apero])
    end

    it "ne signale ni les surplus ni les menus sans commande" do
      menu.update!(requested_meal_counts: { "dinner" => 1 })
      2.times { add_meal("dinner") }

      expect(menu.missing_meal_counts).to eq({})
      expect(create(:menu, user: create(:user)).missing_meal_counts).to eq({})
    end

    it "compte un repas d'avant les quotas (sans moment) comme un déjeuner" do
      menu.update!(requested_meal_counts: { "lunch" => 2 })
      add_meal(nil)

      expect(menu.missing_meal_counts).to eq({ "lunch" => 1 })
    end
  end

  describe "#reactivate!" do
    it "décoche tous les grocery_items et efface previous_quantity_base avant réactivation" do
      ingredient = create(:ingredient, name: "Riz")
      menu = create(:menu, user: user, status: :archived)
      recipe = build(:recipe, default_servings: 1)
      recipe.preparations.build(ingredient: ingredient, quantity_base: 100)
      recipe.save!
      create(:menu_recipe, menu: menu, recipe: recipe, number_of_people: 1)

      generated = create(:grocery_item, menu: menu, ingredient: ingredient, source: :generated,
                                        quantity_base: 100, checked: true, previous_quantity_base: 50)
      manual = create(:grocery_item, menu: menu, ingredient: nil, source: :manual,
                                     name: "Film alimentaire", checked: true)

      menu.reactivate!

      expect(menu.reload).to be_status_active
      expect(generated.reload.checked).to be false
      expect(generated.previous_quantity_base).to be_nil
      expect(manual.reload.checked).to be false
    end

    it "lève une erreur métier depuis un menu qui n'est pas archivé" do
      menu = create(:menu, user: user, status: :active)

      expect { menu.reactivate! }.to raise_error(Menu::InvalidTransitionError, /archivé/)
    end
  end
end
