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

    it "lève une erreur depuis un brouillon" do
      menu = create(:menu, user: user, status: :draft)

      expect { menu.revert_to_draft! }.to raise_error(/actif/)
    end

    it "lève une erreur depuis un menu archivé" do
      menu = create(:menu, user: user, status: :archived)

      expect { menu.revert_to_draft! }.to raise_error(/actif/)
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
  end
end
