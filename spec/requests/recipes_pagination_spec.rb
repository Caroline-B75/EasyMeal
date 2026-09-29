# frozen_string_literal: true

require "rails_helper"

# La nav de Pagy est une String brute : HAML l'échappe avec `=`, et la
# pagination s'affiche alors en texte (`<nav class="pagy nav">…`) au lieu des
# liens de pages. Ces exemples gardent le `!=` en place dans les deux vues
# paginées des recettes, ainsi que les libellés français de la nav.
RSpec.describe "Pagination des recettes", type: :request do
  # Une nav échappée commence par `&lt;nav` dans le corps de la réponse.
  let(:escaped_nav) { "&lt;nav" }

  describe "GET /recipes" do
    before { create_list(:recipe, RecipesController::PER_PAGE + 1, :with_ingredient) }

    it "rend la nav de pages en HTML, pas en texte échappé" do
      get recipes_path

      expect(response.body).to include('<nav class="pagy nav"')
      expect(response.body).not_to include(escaped_nav)
    end

    it "annonce ses flèches en français" do
      get recipes_path

      expect(response.body).to include('aria-label="Précédent"', 'aria-label="Suivant"')
    end

    # Vieux lien, ou filtre ajouté depuis la page 2 : une page qui n'existe plus
    # levait Pagy::OverflowError (erreur 500). On retombe sur la dernière.
    it "affiche la dernière page quand la page demandée n'existe pas" do
      oldest = Recipe.order(:id).first
      oldest.update!(name: "La plus ancienne")

      get recipes_path(page: 99)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("La plus ancienne")
    end
  end

  describe "GET /recipes/:id" do
    let(:recipe) { create(:recipe, :with_ingredient) }

    # Un avis par utilisateur (unicité recipe_id / user_id) : 11 avis = 2 pages.
    before { 11.times { create(:review, recipe: recipe, user: create(:user)) } }

    it "rend la nav des avis en HTML, pas en texte échappé" do
      get recipe_path(recipe)

      expect(response.body).to include('<nav class="pagy nav"')
      expect(response.body).not_to include(escaped_nav)
    end
  end
end
