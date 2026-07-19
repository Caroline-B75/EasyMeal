require "rails_helper"

RSpec.describe "Recipe imports (import IA)", type: :request do
  let(:admin) { create(:user, admin: true) }

  before { sign_in admin }

  describe "GET /recipe_imports/new" do
    it "rend le formulaire d'import avec onglets accessibles, réassurance et aperçu" do
      get new_recipe_import_path

      expect(response).to have_http_status(:ok)
      # Onglets accessibles (pattern ARIA tablist)
      expect(response.body).to include('role="tablist"')
      expect(response.body).to include('role="tab"')
      expect(response.body).to include('aria-selected="true"')
      # Zone d'aperçu de la photo sélectionnée
      expect(response.body).to include("import-file-preview")
      # Message de réassurance avant publication
      expect(response.body).to include("compléter la recette avant de la publier")
      # Bouton de soumission avec spinner d'état de chargement
      expect(response.body).to include("import-submit-spinner")
      expect(response.body).to include("Extraire la recette avec l'IA")
    end
  end
end
