# frozen_string_literal: true

require "rails_helper"

RSpec.describe Menu, type: :model do
  let(:user) { create(:user) }

  describe "validations" do
    it "n'autorise qu'un seul brouillon par foyer" do
      create(:menu, user: user, status: :draft)

      duplicate = build(:menu, user: user, status: :draft)

      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:household_id]).to include("a déjà un menu à valider")
    end
  end

  # Le menu appartient au foyer : ses règles d'unicité et son accès valent pour
  # tous les membres, quel que soit celui qui agit.
  describe "partage dans le foyer" do
    let(:partner) { create(:user).tap { |member| user.household.admit!(member) } }

    it "archive le menu actif validé par un autre membre du foyer" do
      previous_active = create(:menu, user: partner, status: :active)
      menu = create(:menu, user: user, status: :draft)

      menu.activate!

      expect(previous_active.reload).to be_status_archived
      expect(user.menus.active_menus.sole).to eq(menu)
    end

    it "est accessible à chaque membre du foyer, et à eux seuls" do
      menu = create(:menu, user: user)

      expect(menu.household_member?(partner)).to be(true)
      expect(menu.household_member?(create(:user))).to be(false)
      expect(menu.household_member?(nil)).to be(false)
    end
  end

  # « Je m'en occupe » pour tout un rayon
  describe "répartition d'un rayon" do
    let(:partner) { create(:user) }
    let(:menu) { create(:menu, user: user, status: :active) }
    let!(:free_item) { create(:grocery_item, menu: menu, category: :fruits_legumes) }
    let!(:partner_item) { create(:grocery_item, menu: menu, category: :fruits_legumes, claimed_by: partner) }
    let!(:other_section_item) { create(:grocery_item, menu: menu, category: :boissons) }

    it "prend les articles libres du rayon, et eux seuls" do
      menu.claim_grocery_section!("fruits_legumes", user)

      expect(free_item.reload.claimed_by).to eq(user)
      expect(partner_item.reload.claimed_by).to eq(partner)
      expect(other_section_item.reload.claimed_by).to be_nil
    end

    it "laisse les articles du rayon qu'on avait pris, pas ceux des autres" do
      menu.claim_grocery_section!("fruits_legumes", user)

      menu.release_grocery_section!("fruits_legumes", user)

      expect(free_item.reload.claimed_by).to be_nil
      expect(partner_item.reload.claimed_by).to eq(partner)
    end

    it "sait répartir le rayon « Divers » des articles sans rayon" do
      unsorted = create(:grocery_item, menu: menu, category: nil)

      menu.claim_grocery_section!(nil, user)

      expect(unsorted.reload.claimed_by).to eq(user)
      expect(free_item.reload.claimed_by).to be_nil
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

  describe "#usual_groceries_pending?" do
    let(:menu) { create(:menu, user: user, status: :active) }

    it "attend les habituels du foyer tant qu'aucune ligne n'en porte" do
      expect(menu.usual_groceries_pending?).to be false

      user.household.usual_grocery_items.create!(name: "Dentifrice")
      expect(menu.usual_groceries_pending?).to be true

      create(:grocery_item, menu: menu, ingredient: nil, source: :manual, name: "Dentifrice",
                            base_unit: "piece", quantity_base: 1, usual_quantity_base: 1)
      expect(menu.usual_groceries_pending?).to be false
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

    # Les habituels d'il y a des semaines ne disent plus rien : on les rajoute d'un clic.
    it "retire les parts habituelles de la liste" do
      ingredient = create(:ingredient, name: "Riz")
      menu = create(:menu, user: user, status: :archived)
      recipe = build(:recipe, default_servings: 1)
      recipe.preparations.build(ingredient: ingredient, quantity_base: 100)
      recipe.save!
      create(:menu_recipe, menu: menu, recipe: recipe, number_of_people: 1)

      mixed = create(:grocery_item, menu: menu, ingredient: ingredient, source: :generated,
                                    quantity_base: 1100, usual_quantity_base: 1000)
      one_off_and_usual = create(:grocery_item, menu: menu, ingredient: nil, source: :manual, name: "Éponges",
                                                base_unit: "piece", quantity_base: 3, usual_quantity_base: 2)
      usual_only = create(:grocery_item, menu: menu, ingredient: nil, source: :manual, name: "Dentifrice",
                                         base_unit: "piece", quantity_base: 1, usual_quantity_base: 1)

      menu.reactivate!

      expect(mixed.reload).to have_attributes(quantity_base: 100, usual_quantity_base: nil)
      expect(one_off_and_usual.reload).to have_attributes(quantity_base: 1, usual_quantity_base: nil)
      expect(GroceryItem.exists?(usual_only.id)).to be false
    end

    it "lève une erreur métier depuis un menu qui n'est pas archivé" do
      menu = create(:menu, user: user, status: :active)

      expect { menu.reactivate! }.to raise_error(Menu::InvalidTransitionError, /archivé/)
    end
  end
end
