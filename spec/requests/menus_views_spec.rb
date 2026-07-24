# frozen_string_literal: true

require "rails_helper"

# Vérifie que les vues touchées par la clarification actif / menu à valider se
# rendent sans erreur et affichent les nouveaux éléments.
RSpec.describe "Vues menus R3.2bis", type: :request do
  let(:user) { create(:user) }

  before { sign_in user }

  def recipe_with_ingredient
    recipe = build(:recipe, default_servings: 1)
    recipe.preparations.build(ingredient: create(:ingredient), quantity_base: 100)
    recipe.save!
    recipe
  end

  describe "GET /menus avec un brouillon existant" do
    it "signale qu'un nouveau menu remplacera le menu à valider" do
      draft = create(:menu, user: user, status: :draft, name: "Menu à continuer")

      get menus_path

      expect(response).to have_http_status(:success)
      expect(response.body).to include(draft.name, "Créer un nouveau menu le remplacera", "Menu à valider")
    end
  end

  describe "GET /menus/:id d'un menu actif" do
    it "affiche le bouton « Modifier ce menu »" do
      menu = create(:menu, user: user, status: :active)

      get menu_path(menu)

      expect(response).to have_http_status(:success)
      expect(response.body).to include("Modifier ce menu")
      expect(response.body).to include("Actif")
    end
  end

  describe "GET /menus/:id d'un brouillon en revalidation avec menu actif existant" do
    it "affiche une confirmation de validation honnête (réconciliation + archivage)" do
      create(:menu, user: user, status: :active)
      draft = create(:menu, user: user, status: :draft)
      draft.grocery_items.create!(name: "Reste", quantity_base: 1, base_unit: "piece", source: :generated)
      create(:menu_recipe, menu: draft, recipe: recipe_with_ingredient, number_of_people: 1)

      get menu_path(draft)

      expect(response).to have_http_status(:success)
      expect(response.body).to include("Ta liste existante sera mise à jour")
      expect(response.body).to include("Ton menu actif actuel sera archivé")
      expect(response.body).to include("Revalider les modifications")
    end
  end

  describe "GET /menus/:id/grocery avec un article à quantité augmentée" do
    it "affiche le badge de quantité augmentée avec l'ancienne quantité" do
      menu = create(:menu, user: user, status: :active)
      create(:grocery_item, menu: menu, source: :generated,
                            unit_group: :mass, base_unit: "g",
                            quantity_base: 2000, previous_quantity_base: 1500, checked: false)

      get grocery_menu_path(menu)

      expect(response).to have_http_status(:success)
      expect(response.body).to include("Tu en as peut-être déjà acheté 1,5 kg avant ta modification du menu")
    end
  end
end
