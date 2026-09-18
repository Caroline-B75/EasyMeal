# frozen_string_literal: true

require "rails_helper"

# Les courses habituelles du foyer (UC8, étape 3) : ce qui a été saisi, gardé tel
# quel, décrit comme l'ajout d'un article à la liste de courses.
RSpec.describe UsualGroceryItem, type: :model do
  let(:user) { create(:user) }
  let(:household) { user.household }
  let!(:lait) do
    create(:ingredient, name: "Lait demi-écrémé", category: :produits_laitiers,
                        unit_group: :volume, base_unit: "ml")
  end

  def add(**attributes)
    household.usual_grocery_items.create(**attributes)
  end

  describe "article du catalogue" do
    # Le rayon vient de l'ingrédient, comme sur la liste de courses ; recopié,
    # il reste le rayon de repli si l'ingrédient quitte le catalogue.
    it "prend le nom et le rayon de l'ingrédient reconnu par son nom" do
      item = add(name: "lait demi-ecreme", quantity: 6, unit: "l", category: "hygiene_beaute")

      expect(item).to be_persisted
      expect(item).to have_attributes(ingredient: lait, name: "Lait demi-écrémé",
                                      category: "produits_laitiers", quantity: 6, unit: "l")
    end

    it "prend l'ingrédient posé par l'autocomplétion" do
      item = add(name: "Lait", ingredient_id: lait.id, quantity: 1, unit: "l")

      expect(item.ingredient).to eq(lait)
    end

    it "refuse une unité que l'ingrédient ne sait pas lire" do
      item = add(name: lait.name, quantity: 2, unit: "kg")

      expect(item).not_to be_persisted
      expect(item.errors.full_messages).to include("« Lait demi-écrémé » ne se mesure pas en kg.")
    end

    it "redevient un article libre quand l'ingrédient quitte le catalogue" do
      item = add(name: lait.name, quantity: 6, unit: "l")

      lait.destroy!

      expect(item.reload).to have_attributes(ingredient_id: nil, name: "Lait demi-écrémé",
                                             category: "produits_laitiers")
    end
  end

  describe "article hors catalogue" do
    it "garde le rayon saisi" do
      item = add(name: "Dentifrice", quantity: 1, unit: "piece", category: "hygiene_beaute")

      expect(item).to have_attributes(ingredient_id: nil, category: "hygiene_beaute")
    end

    # Un rayon forgé lèverait à l'assignation de l'enum : c'est une erreur de saisie
    it "refuse un rayon inconnu sans lever d'exception" do
      item = add(name: "Dentifrice", category: "rayon-forgé")

      expect(item).not_to be_persisted
      expect(item.errors[:category]).to be_present
    end
  end

  describe "saisie" do
    # Mêmes règles que l'ajout d'un article : sans unité il se compte, sans
    # quantité il s'en achète un.
    it "compte à la pièce, et par un, ce qu'on saisit sans unité ni quantité" do
      item = add(name: "Papier toilette")

      expect(item).to have_attributes(unit: "piece", quantity: 1)
    end

    it "ramène l'unité à sa forme canonique" do
      expect(add(name: "Eau gazeuse", quantity: 6, unit: "Litres").unit).to eq("l")
    end

    it "refuse une quantité nulle" do
      expect(add(name: "Éponges", quantity: 0)).not_to be_persisted
    end
  end

  describe "unicité dans le foyer" do
    it "refuse un article déjà présent, aux accents et à la casse près" do
      add(name: "Éponges")

      twin = add(name: "eponges")

      expect(twin).not_to be_persisted
      expect(twin.errors.full_messages).to include("« eponges » est déjà dans tes courses habituelles.")
    end

    it "reconnaît le même ingrédient sous un autre nom" do
      lait.update!(aliases: [ "lait" ])
      add(name: "Lait demi-écrémé", quantity: 6, unit: "l")

      expect(add(name: "lait", quantity: 1, unit: "l")).not_to be_persisted
    end

    it "laisse chaque foyer tenir sa propre liste" do
      create(:usual_grocery_item, name: "Éponges")

      expect(add(name: "Éponges")).to be_persisted
    end

    it "n'empêche pas de modifier l'article lui-même" do
      item = add(name: "Éponges")

      expect(item.update(quantity: 3)).to be true
    end
  end

  describe "#added_to?" do
    let(:menu) { create(:menu, user: user, status: :active) }

    it "dit si l'article a déjà rejoint cette liste de courses par les habituels" do
      item = add(name: "Éponges")
      expect(item.added_to?(menu)).to be false

      create(:grocery_item, menu: menu, ingredient: nil, name: "Éponges", source: :manual,
                            base_unit: "piece", quantity_base: 1, usual_quantity_base: 1)

      expect(item.added_to?(menu)).to be true
    end

    # Un ajout ponctuel du même article ne vient pas des habituels
    it "ne compte pas une ligne sans part habituelle" do
      item = add(name: "Éponges")
      create(:grocery_item, menu: menu, ingredient: nil, name: "Éponges", source: :manual)

      expect(item.added_to?(menu)).to be false
    end
  end

  describe "#quantity_for_input" do
    it "écrit une quantité entière sans décimale, et une fraction avec un point" do
      expect(add(name: "Lait", quantity: 6, unit: "l").quantity_for_input).to eq(6)
      expect(add(name: "Farine", quantity: 1.5, unit: "kg").quantity_for_input).to eq("1.5")
    end
  end

  describe ".import_from" do
    let(:menu) { create(:menu, user: user, status: :active) }

    def one_off(name, **attributes)
      create(:grocery_item, menu: menu, ingredient: nil, name: name, source: :manual, **attributes)
    end

    it "reprend les ajouts ponctuels de la liste, et eux seuls" do
      one_off("Éponges", base_unit: "piece", quantity_base: 3, category: :entretien_maison)
      create(:grocery_item, menu: menu, name: "Farine", source: :generated)
      one_off("Liquide vaisselle", base_unit: "piece", quantity_base: 1, usual_quantity_base: 1)

      expect(described_class.import_from(menu)).to eq(1)
      expect(household.usual_grocery_items.sole)
        .to have_attributes(name: "Éponges", quantity: 3, unit: "piece", category: "entretien_maison")
    end

    it "ignore ce qui est déjà dans les habituels" do
      add(name: "Éponges")
      one_off("Éponges", base_unit: "piece", quantity_base: 3)

      expect(described_class.import_from(menu)).to eq(0)
    end

    # « 2 kg » plutôt que « 2000 g » — mais 1234 g ne deviennent pas 1,23 kg
    it "reprend la quantité dans l'unité la plus lisible quand elle tombe juste" do
      one_off("Riz", base_unit: "g", quantity_base: 2000)
      one_off("Lentilles", base_unit: "g", quantity_base: 1234)

      described_class.import_from(menu)

      expect(household.usual_grocery_items.find_by(name: "Riz")).to have_attributes(quantity: 2, unit: "kg")
      expect(household.usual_grocery_items.find_by(name: "Lentilles")).to have_attributes(quantity: 1234, unit: "g")
    end
  end
end
