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

    # Le dépôt et le collage vivent dans le contrôleur Stimulus : côté requêtes,
    # seul leur branchement est vérifiable — c'est lui qui saute si la vue change.
    it "câble le dépôt de fichier sur la zone photo et le collage sur la page" do
      get new_recipe_import_path

      expect(response.body).to include("drop-&gt;import-source#dropPhoto")
      expect(response.body).to include("paste@document-&gt;import-source#paste")
    end

    # La photo est réduite dans le navigateur avant l'envoi : l'aperçu annonce le
    # poids du fichier réellement transmis, via une cible que la vue doit fournir.
    it "réserve dans l'aperçu la place du poids du fichier envoyé" do
      get new_recipe_import_path

      expect(response.body).to include('data-import-source-target="previewSize"')
    end

    # Sur mobile, capture forcerait l'appareil photo et interdirait la galerie :
    # le sélecteur natif propose déjà les deux.
    it "laisse le champ photo ouvert à la galerie comme à l'appareil photo" do
      get new_recipe_import_path

      expect(response.body).not_to include("capture=")
    end

    # Bout de chaîne du retour d'échec : le contrôleur renvoie l'URL dans la
    # redirection, la vue doit la remettre dans le champ.
    it "pré-remplit le champ URL quand elle revient d'un échec d'extraction" do
      get new_recipe_import_path(source_url: "https://exemple.fr/tarte")

      expect(response.body).to include('value="https://exemple.fr/tarte"')
    end

    # L'attente remplace le libellé du bouton par des messages d'étape
    # successifs : sans région live sur CE conteneur, un lecteur d'écran
    # n'annoncerait que le premier.
    it "annonce les messages d'étape de l'attente aux lecteurs d'écran" do
      get new_recipe_import_path

      label_tag = response.body[/<span[^>]*submitLabel[^>]*>/]
      expect(label_tag).to include('aria-live="polite"')
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

    # Comparer le formulaire à la source est le geste central de la validation :
    # la page d'origine doit rester à un clic, sans quitter la saisie en cours.
    it "rappelle la page d'origine d'un import par lien en tête de formulaire" do
      link_draft = create(:recipe, status: :draft, source_type: "url",
                                   source_url: "https://exemple.test/tarte-aux-pommes")

      get edit_recipe_path(link_draft)

      expect(response.body).to include("rf-source")
      expect(response.body).to include('href="https://exemple.test/tarte-aux-pommes"')
      expect(response.body).to include('target="_blank"')
    end

    it "n'affiche pas de rappel de source sur un import photo" do
      photo_draft = create(:recipe, status: :draft, source_type: "photo", source_url: nil)

      get edit_recipe_path(photo_draft)

      expect(response.body).not_to include("rf-source")
    end
  end

  describe "POST /recipe_imports" do
    # Un échec d'extraction doit ramener au formulaire avec le motif : c'est le
    # chemin que les erreurs de ExtractorService court-circuitaient en 500 tant
    # qu'elles remontaient en NameError plutôt qu'en ExtractionError. Et après
    # 15 à 30 s d'attente, l'URL saisie repart avec la redirection : la faire
    # retaper serait la punition de trop.
    it "renvoie au formulaire avec le motif et l'URL saisie quand l'extraction échoue" do
      allow(Recipes::ExtractorService).to receive(:from_url)
        .and_raise(Recipes::ExtractionError, "URL inaccessible (code 404)")

      post recipe_imports_path, params: { source_type: "url", source_url: "https://exemple.fr/tarte" }

      expect(response).to redirect_to(new_recipe_import_path(source_url: "https://exemple.fr/tarte"))
      expect(flash[:alert]).to eq("Extraction échouée : URL inaccessible (code 404)")
    end

    # Un champ fichier ne peut pas être re-rempli par le navigateur : là où
    # l'URL revient toute seule, la photo doit être redemandée explicitement.
    it "invite à rechoisir la photo quand l'extraction d'un import photo échoue" do
      allow(Recipes::ExtractorService).to receive(:from_photo)
        .and_raise(Recipes::ExtractionError, "Aucun texte de recette reconnu")

      # Le contenu du fichier n'a pas d'importance : le contrôleur ne fait que
      # l'encoder en base64 avant de le passer au service, ici simulé.
      post recipe_imports_path, params: {
        source_type: "photo",
        photo_file: Rack::Test::UploadedFile.new(StringIO.new("photo"), "image/jpeg",
                                                 original_filename: "magazine.jpg")
      }

      expect(response).to redirect_to(new_recipe_import_path)
      expect(flash[:alert]).to eq(
        "Extraction échouée : Aucun texte de recette reconnu — choisis à nouveau la photo."
      )
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

    # L'IA ne se contente plus d'extraire ce qui est écrit : elle classe, et le
    # formulaire de validation arrive pré-coché. Le vocabulaire reste fermé —
    # un moment inconnu est écarté, un tag absent du catalogue n'est pas créé.
    it "pré-coche les moments, le budget et les tags suggérés par l'IA" do
      saison = create(:tag, name: "de saison")

      allow(Recipes::ExtractorService).to receive(:from_url).and_return(
        "name"       => "Quiche aux poireaux",
        "diet"       => "vegetarien",
        "price"      => "economique",
        "meal_types" => [ "dinner", "lunch", "brunch" ],
        "tags"       => [ "De Saison", "tag inexistant" ]
      )

      post recipe_imports_path, params: { source_type: "url", source_url: "https://exemple.fr/quiche" }

      recipe = Recipe.last
      expect(recipe).to have_attributes(diet: "vegetarien", price: "economique")
      # Rangés dans l'ordre où la journée se déroule, « brunch » écarté.
      expect(recipe.meal_types).to eq([ "lunch", "dinner" ])
      # Le tag est retrouvé malgré la casse ; le nom inconnu est ignoré.
      expect(recipe.tags).to eq([ saison ])
      # Et la liste des brouillons ne réclame plus le moment du repas.
      expect(recipe.draft_missing_fields).not_to include("Moment du repas")
    end
  end
end
