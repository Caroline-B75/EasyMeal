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

  describe "GET /recipes/:id/edit — revue du brouillon importé" do
    let(:draft) do
      create(:recipe, status: :draft, ai_raw_data: {
        "ingredients" => [ { "name" => "farine de blé", "quantity" => 200, "unit" => "g" } ]
      })
    end

    it "rend le panneau IA et confie l'ouverture du formulaire d'ingrédient au slideout" do
      get edit_recipe_path(draft)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Ingrédients détectés par l'IA", "farine de blé")
      # Le panneau demande l'ouverture par événement plutôt que d'ajouter les
      # classes lui-même : seul slideout#open remet le formulaire à neuf entre
      # deux créations d'ingrédient. En retour, il oublie sa ligne en attente
      # quand le slideout se referme sans création.
      expect(response.body).to include("ai-panel:openIngredientForm",
                                       "slideout:closed@document-&gt;ai-panel#forgetPending")
    end

    # Sans échappatoire manuelle, un ingrédient non détecté n'a d'autre issue
    # que la création d'un doublon de celui qui existe déjà au catalogue.
    it "propose de chercher soi-même l'ingrédient dans le catalogue" do
      get edit_recipe_path(draft)

      expect(response.body).to include(search_ingredients_path)
      expect(response.body).to include("ai-panel#openSearch")
      expect(response.body).to include("ai-panel#searchCatalog")
      # Sans détection, les actions de repli sont visibles d'emblée : l'attribut
      # hidden doit être absent, pas rendu à "false" (qui masquerait quand même).
      expect(response.body).not_to include("hidden='false'", 'hidden="false"')
    end

    it "propose de changer d'ingrédient même quand la détection est sûre d'elle" do
      create(:ingredient, name: "farine de blé")

      get edit_recipe_path(draft)

      # La ligne est résolue (bouton Ajouter) mais garde sa porte de sortie
      expect(response.body).to include("Choisir un autre")
    end

    it "propose d'abandonner l'import, à l'écart des actions du formulaire" do
      get edit_recipe_path(draft)

      # Le bloc est hors du formulaire recette : il porte sa propre classe et
      # vise la route de suppression des brouillons.
      expect(response.body).to include("rf-discard")
      expect(response.body).to include(recipe_draft_path(draft))
      expect(response.body).to include("Supprimer définitivement cet import")
    end

    it "ne propose pas d'abandon sur une recette publiée" do
      get edit_recipe_path(create(:recipe, :with_ingredient))

      expect(response.body).not_to include("rf-discard")
    end
  end

  describe "POST /recipe_imports" do
    # Un échec d'extraction doit ramener au formulaire avec le motif : c'est le
    # chemin que les erreurs de ExtractorService court-circuitaient en 500 tant
    # qu'elles remontaient en NameError plutôt qu'en ExtractionError.
    it "renvoie au formulaire avec le motif quand l'extraction échoue" do
      allow(Recipes::ExtractorService).to receive(:from_url)
        .and_raise(Recipes::ExtractionError, "URL inaccessible (code 404)")

      post recipe_imports_path, params: { source_type: "url", source_url: "https://exemple.fr/tarte" }

      expect(response).to redirect_to(new_recipe_import_path)
      expect(flash[:alert]).to eq("Extraction échouée : URL inaccessible (code 404)")
    end

    it "crée un brouillon et ouvre le formulaire de review quand l'extraction réussit" do
      allow(Recipes::ExtractorService).to receive(:from_url).and_return(
        "name" => "Tarte aux poireaux", "default_servings" => 6, "diet" => "vegetarien"
      )

      expect {
        post recipe_imports_path, params: { source_type: "url", source_url: "https://exemple.fr/tarte" }
      }.to change(Recipe, :count).by(1)

      recipe = Recipe.last
      expect(recipe).to have_attributes(
        status: "draft", source_type: "url", name: "Tarte aux poireaux",
        default_servings: 6, diet: "vegetarien"
      )
      expect(response).to redirect_to(edit_recipe_path(recipe))
    end
  end
end
