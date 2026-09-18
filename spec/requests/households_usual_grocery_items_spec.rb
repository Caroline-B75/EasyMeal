# frozen_string_literal: true

require "rails_helper"

# La page « Courses habituelles » du foyer (UC8, étape 3) : ce que le foyer
# achète chaque semaine, saisi une fois avec le formulaire de la liste de courses.
RSpec.describe "Courses habituelles du foyer", type: :request do
  let(:user) { create(:user) }
  let(:household) { user.household }

  before { sign_in user }

  def usual(**attributes)
    household.usual_grocery_items.create!(**attributes)
  end

  describe "GET /foyer/courses-habituelles" do
    it "range les articles par rayon, avec le formulaire d'ajout de la liste de courses" do
      usual(name: "Dentifrice", category: "hygiene_beaute")
      create(:usual_grocery_item, name: "Caviar")

      get household_usual_grocery_items_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Mes courses habituelles", "Hygiène", "Dentifrice",
                                       'usual-rayon" data-category="hygiene_beaute"',
                                       "Ajouter un habituel", "grocery-add-form--compact", "ingredient-combobox")
      expect(response.body).not_to include("Caviar")
    end

    # La quantité se lit dans une pastille, qui ouvre l'éditeur de la ligne
    it "donne à chaque article sa pastille de quantité et son éditeur" do
      usual(name: "Riz", quantity: 500, unit: "g")
      usual(name: "Éponges", quantity: 3)

      get household_usual_grocery_items_path

      expect(response.body).to include("2 articles que le foyer achète",
                                       "Modifier la quantité de Riz : 500 g", "Modifier la quantité de Éponges : 3",
                                       "usual-item-editor", 'data-number-stepper-increment-value="50"',
                                       "Retirer des habituelles")
    end

    it "mène à la liste de courses quand il y en a une, à « Mon foyer » sinon" do
      get household_usual_grocery_items_path
      expect(response.body).to include("Mon foyer")

      menu = create(:menu, user: user, status: :active)
      get household_usual_grocery_items_path
      expect(response.body).to include(grocery_menu_path(menu))
    end

    it "exige d'être connecté" do
      sign_out user

      get household_usual_grocery_items_path

      expect(response).to redirect_to(new_user_session_path)
    end
  end

  describe "GET /foyer" do
    it "mène aux courses habituelles" do
      get household_path
      expect(response.body).to include("Mes courses habituelles", "Créer la liste")

      usual(name: "Dentifrice")
      get household_path
      expect(response.body).to include("1 article, ajouté d", "Gérer la liste",
                                       household_usual_grocery_items_path)
    end
  end

  describe "POST /foyer/courses-habituelles" do
    it "enregistre l'article saisi" do
      post household_usual_grocery_items_path,
           params: { usual_grocery_item: { name: "Éponges", quantity: "3", unit: "piece",
                                           category: "entretien_maison" } }

      expect(response).to redirect_to(household_usual_grocery_items_path)
      expect(flash[:notice]).to include("Éponges")
      expect(household.usual_grocery_items.sole).to have_attributes(name: "Éponges", quantity: 3,
                                                                     category: "entretien_maison")
    end

    it "dit pourquoi un article est refusé" do
      usual(name: "Éponges")

      post household_usual_grocery_items_path, params: { usual_grocery_item: { name: "eponges" } }

      expect(flash[:alert]).to eq("« eponges » est déjà dans tes courses habituelles.")
      expect(household.usual_grocery_items.count).to eq(1)
    end
  end

  describe "PATCH /foyer/courses-habituelles/:id" do
    it "change la quantité et l'unité" do
      item = usual(name: "Riz", quantity: 500, unit: "g")

      patch household_usual_grocery_item_path(item), params: { usual_grocery_item: { quantity: "2", unit: "kg" } }

      expect(item.reload).to have_attributes(quantity: 2, unit: "kg")
    end

    it "ne change pas d'article" do
      item = usual(name: "Riz")

      patch household_usual_grocery_item_path(item), params: { usual_grocery_item: { name: "Caviar" } }

      expect(item.reload.name).to eq("Riz")
    end

    it "ne touche pas aux habituels d'un autre foyer" do
      foreign = create(:usual_grocery_item, quantity: 1)

      patch household_usual_grocery_item_path(foreign), params: { usual_grocery_item: { quantity: "9" } }

      expect(response).to have_http_status(:not_found)
      expect(foreign.reload.quantity).to eq(1)
    end
  end

  describe "DELETE /foyer/courses-habituelles/:id" do
    it "retire l'article des habituels" do
      item = usual(name: "Dentifrice")

      delete household_usual_grocery_item_path(item)

      expect(household.usual_grocery_items.reload).to be_empty
      expect(flash[:notice]).to include("Dentifrice")
    end
  end

  describe "POST /foyer/courses-habituelles/reprendre" do
    it "reprend les ajouts ponctuels de la liste de courses" do
      menu = create(:menu, user: user, status: :active)
      create(:grocery_item, menu: menu, ingredient: nil, source: :manual, name: "Piles")

      post import_household_usual_grocery_items_path, params: { menu_id: menu.id }

      expect(response).to redirect_to(household_usual_grocery_items_path)
      expect(flash[:notice]).to eq("1 article repris de ta liste de courses : vérifie les quantités.")
      expect(household.usual_grocery_items.pluck(:name)).to eq([ "Piles" ])
    end

    it "ne lit pas la liste de courses d'un autre foyer" do
      foreign_menu = create(:menu, status: :active)
      create(:grocery_item, menu: foreign_menu, ingredient: nil, source: :manual, name: "Caviar")

      post import_household_usual_grocery_items_path, params: { menu_id: foreign_menu.id }

      expect(response).to have_http_status(:not_found)
      expect(household.usual_grocery_items).to be_empty
    end
  end
end
