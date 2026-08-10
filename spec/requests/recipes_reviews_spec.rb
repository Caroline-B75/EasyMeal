require "rails_helper"

RSpec.describe "Avis sur une recette", type: :request do
  let(:user) { create(:user) }
  let(:recipe) { create(:recipe, :with_ingredient) }

  before { sign_in user }

  describe "POST /recipes/:recipe_id/reviews" do
    it "enregistre l'avis et l'ajoute à la liste" do
      expect {
        post recipe_reviews_path(recipe),
             params: { rating: 4, content: "Excellent !" },
             as: :turbo_stream
      }.to change(Review, :count).by(1)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Excellent !")
    end

    it "réaffiche le formulaire avec l'erreur et le commentaire saisi quand la note manque" do
      expect {
        post recipe_reviews_path(recipe),
             params: { content: "J'ai oublié les étoiles" },
             as: :turbo_stream
      }.not_to change(Review, :count)

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include("La note doit être comprise entre 1 et 5 étoiles")
      # La saisie de l'utilisateur n'est pas perdue
      expect(response.body).to include("J&#39;ai oublié les étoiles")
    end
  end
end
