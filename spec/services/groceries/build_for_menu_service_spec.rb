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

  describe ".call — recette répétée dans le menu (UC7)" do
    it "additionne les quantités des doublons" do
      menu = menu_with(ingredient => 100)
      # La même recette une seconde fois : la levée de l'unicité menu/recette ne
      # doit pas faire « oublier » l'un des deux repas à la liste de courses.
      create(:menu_recipe, menu: menu, recipe: menu.menu_recipes.first.recipe, number_of_people: 1)

      described_class.call(menu: menu)

      expect(menu.menu_recipes.count).to eq(2)
      item = menu.grocery_items.generated.find_by(ingredient: ingredient)
      expect(item.quantity_base).to eq(200)
    end
  end

  # Deux recettes peuvent doser le même ingrédient dans deux unités différentes —
  # « 2 càs d'huile » ici, « 5 ml » là. L'addition reste juste parce qu'une
  # quantité n'est jamais stockée autrement que dans l'unité de base de son
  # ingrédient : le sélecteur d'unité du formulaire de recette convertit à la
  # saisie (Units), il ne laisse pas une unité voyager jusqu'ici.
  describe ".call — un ingrédient dosé dans deux unités" do
    it "additionne des cuillerées et des millilitres dans l'unité de base" do
      huile = create(:ingredient, name: "Huile d'olive", unit_group: :volume, base_unit: "ml")
      cuillerees = UnitConversionService.convert(quantity: 2, from_unit: "càs", ingredient: huile)
      millilitres = UnitConversionService.convert(quantity: 5, from_unit: "ml", ingredient: huile)

      menu = menu_with(huile => cuillerees)
      autre = build(:recipe, default_servings: 1)
      autre.preparations.build(ingredient: huile, quantity_base: millilitres)
      autre.save!
      create(:menu_recipe, menu: menu, recipe: autre, number_of_people: 1)

      described_class.call(menu: menu)

      item = menu.grocery_items.generated.find_by(ingredient: huile)
      # 2 càs = 30 ml, plus 5 ml
      expect(item.quantity_base).to eq(35)
      expect(item.base_unit).to eq("ml")
      expect(Quantities::HumanizeService.call(quantity: item.quantity_base, unit_group: item.unit_group)[:display])
        .to eq("35 ml")
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

  # Un ingrédient retiré du catalogue laisse ses lignes de courses derrière lui
  # (dependent: :nullify) : elles partagent alors toutes la clé nil, et la
  # réconciliation doit les nettoyer TOUTES — un index par ingrédient n'en aurait
  # vu qu'une, les autres seraient restées à jamais dans la liste.
  describe ".call — lignes générées orphelines d'un ingrédient supprimé" do
    it "détruit toutes les lignes générées dont l'ingrédient a disparu" do
      menu = menu_with(ingredient => 100)
      orphelines = Array.new(2) do |i|
        create(:grocery_item, menu: menu, ingredient: nil, source: :generated,
                              name: "Disparu #{i}", quantity_base: 50)
      end

      described_class.call(menu: menu)

      expect(GroceryItem.where(id: orphelines.map(&:id))).to be_empty
      expect(menu.grocery_items.generated.pluck(:name)).to eq([ "Farine" ])
    end
  end

  # Courses habituelles (UC8, étape 3) : une ligne = la part du menu, recalculée,
  # plus la part habituelle, conservée.
  describe ".call — part habituelle" do
    def usual_line(menu, ing, quantity:, usual:, source:, checked: false)
      create(:grocery_item, menu: menu, ingredient: ing, name: ing.name, source: source,
                            quantity_base: quantity, usual_quantity_base: usual, checked: checked)
    end

    it "(règle 4) ajoute la part habituelle à la quantité recalculée du menu" do
      menu = menu_with(ingredient => 300)
      item = usual_line(menu, ingredient, quantity: 1100, usual: 1000, source: :generated)

      described_class.call(menu: menu)

      expect(item.reload).to have_attributes(quantity_base: 1300, usual_quantity_base: 1000, source: "generated")
    end

    it "(règle 5) garde la part habituelle d'une ligne que le menu ne demande plus" do
      sucre = create(:ingredient, name: "Sucre")
      menu = menu_with(ingredient => 100)
      item = usual_line(menu, sucre, quantity: 1200, usual: 1000, source: :generated, checked: true)

      described_class.call(menu: menu)

      expect(item.reload).to have_attributes(source: "manual", quantity_base: 1000, usual_quantity_base: 1000,
                                             checked: true, previous_quantity_base: nil)
    end

    it "(règle 6) fait rejoindre le menu à une ligne entièrement habituelle" do
      menu = menu_with(ingredient => 300)
      item = usual_line(menu, ingredient, quantity: 1000, usual: 1000, source: :manual, checked: true)

      described_class.call(menu: menu)

      expect(menu.grocery_items.sole).to eq(item)
      expect(item.reload).to have_attributes(source: "generated", quantity_base: 1300, usual_quantity_base: 1000,
                                             checked: false, previous_quantity_base: 1000)
    end

    # Comme tout ajout manuel, une ligne qui compte un ajout ponctuel cohabite
    # avec la ligne du menu : elle n'est jamais adoptée.
    it "n'adopte pas une ligne qui compte un ajout ponctuel" do
      menu = menu_with(ingredient => 300)
      item = usual_line(menu, ingredient, quantity: 1500, usual: 1000, source: :manual)

      described_class.call(menu: menu)

      expect(item.reload).to have_attributes(source: "manual", quantity_base: 1500)
      expect(menu.grocery_items.generated.sole.quantity_base).to eq(300)
    end

    it "reste idempotent" do
      menu = menu_with(ingredient => 300)
      usual_line(menu, ingredient, quantity: 1000, usual: 1000, source: :manual)
      described_class.call(menu: menu)

      expect { described_class.call(menu: menu) }
        .not_to(change { menu.grocery_items.pluck(:quantity_base, :updated_at) })
    end
  end
end
