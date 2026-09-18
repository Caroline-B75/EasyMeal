# frozen_string_literal: true

require "rails_helper"

# Les courses habituelles rejoignent la liste de courses (UC8, étape 3), par le
# chemin de l'ajout d'un article : même rayon, même conversion. Un article déjà
# dans la liste y voit sa quantité additionnée.
RSpec.describe Groceries::AddUsualItemsService do
  let(:user) { create(:user) }
  let(:menu) { create(:menu, user: user, status: :active) }
  let(:lait) do
    create(:ingredient, name: "Lait demi-écrémé", category: :produits_laitiers,
                        unit_group: :volume, base_unit: "ml")
  end
  let(:lait_habituel) { usual(name: lait.name, quantity: 6, unit: "l") }

  def usual(**attributes)
    user.household.usual_grocery_items.create!(**attributes)
  end

  def add(selections)
    described_class.call(menu: menu, selections: selections)
  end

  describe "article absent de la liste" do
    it "crée une ligne entièrement habituelle, rangée et convertie comme un ajout manuel" do
      summary = add(lait_habituel => 6)

      expect(menu.grocery_items.sole).to have_attributes(
        ingredient: lait, category: "produits_laitiers", source: "manual",
        base_unit: "ml", quantity_base: 6000, usual_quantity_base: 6000
      )
      expect(summary.message).to eq("1 article ajouté à ta liste.")
    end

    it "range un article hors catalogue dans son rayon" do
      add(usual(name: "Dentifrice", category: "hygiene_beaute") => 1)

      expect(menu.grocery_items.sole).to have_attributes(name: "Dentifrice", ingredient_id: nil,
                                                         category: "hygiene_beaute", usual_quantity_base: 1)
    end

    it "retient la quantité de cette fois, sans toucher aux habituels" do
      add(lait_habituel => 2)

      expect(menu.grocery_items.sole.quantity_base).to eq(2000)
      expect(lait_habituel.reload.quantity).to eq(6)
    end
  end

  describe "article déjà dans la liste" do
    let!(:line) do
      create(:grocery_item, menu: menu, ingredient: lait, name: lait.name, source: :generated,
                            base_unit: "ml", quantity_base: 500)
    end

    it "additionne la quantité à la ligne du menu, qui retient sa part habituelle" do
      summary = add(lait_habituel => 6)

      expect(menu.grocery_items.sole).to eq(line)
      expect(line.reload).to have_attributes(quantity_base: 6500, usual_quantity_base: 6000, source: "generated")
      expect(summary.message).to eq("1 article ajouté à ta liste, dont 1 additionné à une ligne existante.")
    end

    it "décoche une ligne déjà achetée, en retenant ce qui l'a été" do
      line.update!(checked: true)

      add(lait_habituel => 6)

      expect(line.reload).to have_attributes(checked: false, previous_quantity_base: 500)
    end

    it "additionne encore si on rajoute volontairement les habituels" do
      add(lait_habituel => 6)
      add(lait_habituel => 1)

      expect(line.reload).to have_attributes(quantity_base: 7500, usual_quantity_base: 7000)
    end
  end

  # Des paquets face à des grammes ne s'additionnent pas : l'habituel prend une
  # ligne à part plutôt que de fausser la quantité.
  it "donne une ligne à part à un article dont l'unité ne s'additionne pas" do
    create(:grocery_item, menu: menu, ingredient: nil, name: "Café", source: :manual,
                          base_unit: "g", quantity_base: 250)

    summary = add(usual(name: "Café", quantity: 2, unit: "piece") => 2)

    expect(menu.grocery_items.where(name: "Café").pluck(:base_unit, :usual_quantity_base))
      .to contain_exactly([ "g", nil ], [ "piece", 2 ])
    expect(summary.added).to eq(1)
  end

  # L'ingrédient ne sait plus lire l'unité enregistrée (le catalogue a changé) :
  # l'article est nommé dans le bilan, les autres sont ajoutés.
  it "nomme l'article refusé sans empêcher les autres" do
    stale = lait_habituel
    lait.update_columns(unit_group: Ingredient.unit_groups[:mass], base_unit: "g")

    summary = add(stale => 6, usual(name: "Dentifrice") => 1)

    expect(menu.grocery_items.pluck(:name)).to eq([ "Dentifrice" ])
    expect(summary.message).to eq("1 article ajouté à ta liste. « Lait demi-écrémé » ne se mesure pas en L.")
  end

  it "dit quand rien n'a été ajouté" do
    summary = add({})

    expect(summary).not_to be_any_added
    expect(summary.message).to eq("Aucun article n'a été ajouté.")
  end

  it "accorde le bilan au pluriel" do
    create(:grocery_item, menu: menu, ingredient: nil, name: "Éponges", source: :manual,
                          base_unit: "piece", quantity_base: 1)
    create(:grocery_item, menu: menu, ingredient: nil, name: "Café", source: :manual,
                          base_unit: "piece", quantity_base: 1)
    selections = %w[Éponges Café Dentifrice].to_h { |name| [ usual(name: name), 1 ] }

    expect(add(selections).message).to eq("3 articles ajoutés à ta liste, dont 2 additionnés à des lignes existantes.")
  end
end
