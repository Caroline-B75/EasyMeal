require "rails_helper"

RSpec.describe "Recipe drafts (recettes importées)", type: :request do
  let(:admin) { create(:user, admin: true) }

  before { sign_in admin }

  describe "GET /recipe_drafts" do
    it "affiche l'état vide quand aucun brouillon n'existe" do
      get recipe_drafts_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Aucune recette importée")
    end

    it "priorise visuellement un brouillon incomplet et liste les champs manquants" do
      create(:recipe,
             status: :draft,
             name: Recipe::PLACEHOLDER_NAME,
             instructions: nil,
             source_type: "url")

      get recipe_drafts_path

      expect(response).to have_http_status(:ok)
      # État "à compléter" + priorisation visuelle
      expect(response.body).to include("draft-card--todo")
      expect(response.body).to include("À compléter")
      # Champs manquants listés (titre placeholder, pas d'ingrédient, pas d'instructions)
      expect(response.body).to include("Titre")
      expect(response.body).to include("Ingrédients")
      expect(response.body).to include("Instructions")
      # Badge de source lisible
      expect(response.body).to include("badge--source")
      expect(response.body).to include("Lien")
    end

    it "marque un brouillon complet comme prêt à valider" do
      recipe = create(:recipe,
                      status: :draft,
                      name: "Tarte aux pommes",
                      instructions: "Étaler la pâte puis cuire.",
                      source_type: "photo")
      create(:preparation, recipe: recipe, ingredient: create(:ingredient))

      get recipe_drafts_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("draft-card--ready")
      expect(response.body).to include("Prêt à valider")
      expect(response.body).to include("Photo")
    end
  end
end
