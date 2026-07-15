# frozen_string_literal: true

require "rails_helper"

# Réconciliation intelligente de la liste de courses (R3.2bis).
# On sépare la « nouvelle » quantité (portée par la préparation de la recette,
# recalculée par le service) de « l'ancienne » quantité (portée par le GroceryItem
# généré déjà persisté). scale_factor = number_of_people / default_servings = 1
# (default_servings 1, number_of_people 1) → la quantité de la préparation est
# reprise telle quelle.
RSpec.describe Groceries::BuildForMenuService do
  let(:user) { create(:user) }
  let(:ingredient) { create(:ingredient, name: "Farine", unit_group: :mass, base_unit: "g") }

  # Construit un menu dont la préparation fixe la NOUVELLE quantité agrégée d'un ingrédient.
  def menu_with(new_quantities)
    menu = create(:menu, user: user)
    # Recette + préparations créées ensemble : une recette publiée exige >= 1 ingrédient.
    recipe = build(:recipe, default_servings: 1)
    new_quantities.each do |ing, qty|
      recipe.preparations.build(ingredient: ing, quantity_base: qty)
    end
    recipe.save!
    create(:menu_recipe, menu: menu, recipe: recipe, number_of_people: 1)
    menu
  end

  # Crée un item généré « déjà présent » (issu d'une validation précédente).
  def existing_generated(menu, ing, quantity:, checked:, previous: nil)
    create(:grocery_item,
           menu: menu, ingredient: ing, source: :generated,
           quantity_base: quantity, checked: checked, previous_quantity_base: previous)
  end

  describe ".call — règles de réconciliation" do
    it "(a) quantité inchangée : conserve la coche et remet previous_quantity_base à nil" do
      menu = menu_with(ingredient => 100)
      item = existing_generated(menu, ingredient, quantity: 100, checked: true, previous: 50)

      described_class.call(menu: menu)

      item.reload
      expect(item.quantity_base).to eq(100)
      expect(item.checked).to be true
      expect(item.previous_quantity_base).to be_nil
    end

    it "(b) quantité en baisse : met à jour la quantité, conserve la coche, pas de badge" do
      menu = menu_with(ingredient => 80)
      item = existing_generated(menu, ingredient, quantity: 100, checked: true)

      described_class.call(menu: menu)

      item.reload
      expect(item.quantity_base).to eq(80)
      expect(item.checked).to be true
      expect(item.previous_quantity_base).to be_nil
    end

    it "(c) quantité en hausse sur item coché : décoche et mémorise l'ancienne quantité" do
      menu = menu_with(ingredient => 200)
      item = existing_generated(menu, ingredient, quantity: 100, checked: true)

      described_class.call(menu: menu)

      item.reload
      expect(item.quantity_base).to eq(200)
      expect(item.checked).to be false
      expect(item.previous_quantity_base).to eq(100)
    end

    it "(d) quantité en hausse sur item décoché : met à jour la quantité, pas de badge" do
      menu = menu_with(ingredient => 200)
      item = existing_generated(menu, ingredient, quantity: 100, checked: false)

      described_class.call(menu: menu)

      item.reload
      expect(item.quantity_base).to eq(200)
      expect(item.checked).to be false
      expect(item.previous_quantity_base).to be_nil
    end

    it "(e) ingrédient disparu du menu : détruit l'item généré correspondant" do
      other = create(:ingredient, name: "Sucre")
      menu = menu_with(ingredient => 100)                 # le menu ne contient QUE farine
      keep = existing_generated(menu, ingredient, quantity: 100, checked: false)
      gone = existing_generated(menu, other, quantity: 50, checked: false)

      described_class.call(menu: menu)

      expect(GroceryItem.exists?(keep.id)).to be true
      expect(GroceryItem.exists?(gone.id)).to be false
    end

    it "(f) nouvel ingrédient : crée un item généré décoché" do
      menu = menu_with(ingredient => 100)                 # aucun item généré existant

      described_class.call(menu: menu)

      item = menu.grocery_items.generated.find_by(ingredient: ingredient)
      expect(item).to be_present
      expect(item.quantity_base).to eq(100)
      expect(item.checked).to be false
      expect(item.previous_quantity_base).to be_nil
      expect(item.name).to eq("Farine")
    end
  end

  describe ".call — idempotence" do
    it "deux appels consécutifs sans changement de menu ne modifient rien" do
      menu = menu_with(ingredient => 100)
      described_class.call(menu: menu)
      item = menu.grocery_items.generated.first
      item.update!(checked: true)

      expect { described_class.call(menu: menu) }
        .not_to change { menu.grocery_items.generated.count }

      item.reload
      expect(item.checked).to be true                 # coche conservée
      expect(item.quantity_base).to eq(100)
      expect(item.previous_quantity_base).to be_nil
    end
  end

  describe ".call — items manuels" do
    it "ne touche jamais les items source: :manual" do
      menu = menu_with(ingredient => 100)
      manual = create(:grocery_item,
                      menu: menu, ingredient: nil, source: :manual,
                      name: "Éponges", checked: true)

      described_class.call(menu: menu)

      manual.reload
      expect(GroceryItem.exists?(manual.id)).to be true
      expect(manual.source_manual?).to be true
      expect(manual.checked).to be true
      expect(manual.name).to eq("Éponges")
    end
  end
end
