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

    # Un import photo se valide en recopiant une page : elle prend une colonne à
    # elle, tenue sous les yeux pendant toute la saisie, au lieu du rappel
    # d'adresse qui suffit à un import par lien.
    it "montre la page photographiée dans la visionneuse latérale" do
      photo_draft = create(:recipe, :with_source_photo, status: :draft,
                                                        source_type: "photo", source_url: nil)

      get edit_recipe_path(photo_draft)

      expect(response.body).to include("rf-viewer")
      expect(response.body).to include(photo_draft.source_photo.blob.key)
      # Zoom et déplacement vivent dans le contrôleur Stimulus : côté requêtes,
      # seul leur branchement est vérifiable — c'est lui qui saute si la vue change.
      expect(response.body).to include('data-controller="source-viewer"')
      expect(response.body).to include('data-source-viewer-target="image"')
      expect(response.body).to include("source-viewer#wheelZoom")
      # L'image reste ouvrable en plein écran, hors de la saisie en cours.
      expect(response.body).to include('target="_blank"')
      # Pas de bandeau d'adresse : un import photo n'a pas d'URL à rappeler.
      expect(response.body).not_to include("rf-source__label")
    end

    # Import photo antérieur à la conservation de la page photographiée : il n'y a
    # plus rien à montrer, ni bandeau ni visionneuse vide.
    it "n'affiche pas de rappel de source quand la photo importée n'a pas été conservée" do
      photo_draft = create(:recipe, status: :draft, source_type: "photo", source_url: nil)

      get edit_recipe_path(photo_draft)

      expect(response.body).not_to include("rf-source__label")
      expect(response.body).not_to include("rf-viewer")
    end

    # La photo importée est une pièce de référence du brouillon, pas une photo
    # du plat : elle ne doit jamais s'inviter dans la fiche publique.
    it "ne montre pas la photo importée sur une recette publiée" do
      published = create(:recipe, :with_ingredient, :with_source_photo, source_type: "photo")

      get recipe_path(published)

      expect(response.body).not_to include(published.source_photo.blob.key)
    end
  end

  describe "POST /recipe_imports" do
    # La requête ne fait plus que déposer la commande : l'extraction, qui peut
    # demander jusqu'à 60 s, part dans un job. C'est ce qui la met hors de portée
    # du routeur de l'hébergeur, lequel abandonne une requête vers 30 s.
    it "enregistre la commande, la confie au job et emmène à la page d'attente" do
      expect {
        post recipe_imports_path,
             params: { source_type: "url", source_url: "  https://exemple.fr/tarte  " }
      }.to change(RecipeImport, :count).by(1)

      import = RecipeImport.last
      expect(import).to have_attributes(
        status: "pending", source_type: "url",
        source_url: "https://exemple.fr/tarte", user: admin
      )
      expect(Recipes::ImportJob).to have_been_enqueued.with(import)
      expect(response).to redirect_to(recipe_import_path(import))
    end

    it "ne sollicite pas l'IA pendant la requête" do
      expect(Recipes::ExtractorService).not_to receive(:from_url)

      post recipe_imports_path, params: { source_type: "url", source_url: "https://exemple.fr/tarte" }
    end

    # La photo doit survivre à la fin de la requête : le job la relira plus tard,
    # quand le fichier temporaire du navigateur aura disparu.
    it "range la photo sur l'import pour que le job puisse la relire" do
      post recipe_imports_path, params: {
        source_type: "photo",
        photo_file: Rack::Test::UploadedFile.new(StringIO.new("photo"), "image/jpeg",
                                                 original_filename: "magazine.jpg")
      }

      import = RecipeImport.last
      expect(import.source_photo).to be_attached
      expect(import.source_photo.filename.to_s).to eq("magazine.jpg")
    end
  end

  # Le parcours complet, job déroulé. C'est ici que vivent désormais les
  # garanties métier de l'import, depuis que le travail a quitté le contrôleur.
  describe "le parcours complet d'un import" do
    it "crée un brouillon et ouvre le formulaire de review quand l'extraction réussit" do
      allow(Recipes::ExtractorService).to receive(:from_url).and_return(
        "name" => "Tarte aux poireaux", "default_servings" => 6, "diet" => "vegetarien"
      )

      expect {
        perform_enqueued_jobs do
          post recipe_imports_path, params: { source_type: "url", source_url: "https://exemple.fr/tarte" }
        end
      }.to change(Recipe, :count).by(1)

      recipe = Recipe.last
      expect(recipe).to have_attributes(
        status: "draft", source_type: "url", name: "Tarte aux poireaux",
        default_servings: 6, diet: "vegetarien"
      )
      expect(RecipeImport.last).to have_attributes(status: "succeeded", recipe: recipe)

      # La page d'attente constate la réussite et emmène au formulaire.
      follow_redirect!
      expect(response).to redirect_to(edit_recipe_path(recipe))
    end

    # La page photographiée survit à l'extraction : c'est elle qu'on relit
    # pendant la validation quand une quantité paraît douteuse. Elle ne devient
    # pas pour autant la photo du plat.
    it "transmet la photo au brouillon comme pièce de référence" do
      allow(Recipes::ExtractorService).to receive(:from_photo).and_return("name" => "Paella")

      perform_enqueued_jobs { post_photo_import }

      recipe = Recipe.last
      expect(recipe.source_photo).to be_attached
      expect(recipe.source_photo.filename.to_s).to eq("magazine.jpg")
      expect(recipe.photo).not_to be_attached
    end

    # Le fichier change de propriétaire, il n'est pas dupliqué : l'import le
    # lâche une fois le brouillon écrit. Sans ce transfert, les deux
    # enregistrements partageraient le même blob et supprimer l'un emporterait
    # l'image de l'autre.
    it "laisse le brouillon seul propriétaire du fichier de source" do
      allow(Recipes::ExtractorService).to receive(:from_photo).and_return("name" => "Paella")

      perform_enqueued_jobs { post_photo_import }

      expect(RecipeImport.last.source_photo).not_to be_attached
      expect(Recipe.last.source_photo).to be_attached
    end

    it "n'attache aucune photo de source à un import par lien" do
      allow(Recipes::ExtractorService).to receive(:from_url).and_return("name" => "Tarte")

      perform_enqueued_jobs do
        post recipe_imports_path, params: { source_type: "url", source_url: "https://exemple.fr/tarte" }
      end

      expect(Recipe.last.source_photo).not_to be_attached
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

      perform_enqueued_jobs do
        post recipe_imports_path, params: { source_type: "url", source_url: "https://exemple.fr/quiche" }
      end

      recipe = Recipe.last
      expect(recipe).to have_attributes(diet: "vegetarien", price: "economique")
      # Rangés dans l'ordre où la journée se déroule, « brunch » écarté.
      expect(recipe.meal_types).to eq([ "lunch", "dinner" ])
      # Le tag est retrouvé malgré la casse ; le nom inconnu est ignoré.
      expect(recipe.tags).to eq([ saison ])
      # Et la liste des brouillons ne réclame plus le moment du repas.
      expect(recipe.draft_missing_fields).not_to include("Moment du repas")
    end

    # Un échec d'extraction doit ramener au formulaire avec le motif : c'est le
    # chemin que les erreurs de ExtractorService court-circuitaient en 500 tant
    # qu'elles remontaient en NameError plutôt qu'en ExtractionError. Et l'URL
    # saisie repart avec la redirection : la faire retaper serait la punition de
    # trop.
    it "renvoie au formulaire avec le motif et l'URL saisie quand l'extraction échoue" do
      allow(Recipes::ExtractorService).to receive(:from_url)
        .and_raise(Recipes::ExtractionError, "URL inaccessible (code 404)")

      expect {
        perform_enqueued_jobs do
          post recipe_imports_path, params: { source_type: "url", source_url: "https://exemple.fr/tarte" }
        end
      }.not_to change(Recipe, :count)

      follow_redirect!
      expect(response).to redirect_to(new_recipe_import_path(source_url: "https://exemple.fr/tarte"))
      expect(flash[:alert]).to eq("Extraction échouée : URL inaccessible (code 404)")
    end

    # Un champ fichier ne peut pas être re-rempli par le navigateur : là où
    # l'URL revient toute seule, la photo doit être redemandée explicitement.
    it "invite à rechoisir la photo quand l'extraction d'un import photo échoue" do
      allow(Recipes::ExtractorService).to receive(:from_photo)
        .and_raise(Recipes::ExtractionError, "Aucun texte de recette reconnu")

      perform_enqueued_jobs { post_photo_import }

      follow_redirect!
      expect(response).to redirect_to(new_recipe_import_path)
      expect(flash[:alert]).to eq(
        "Extraction échouée : Aucun texte de recette reconnu — choisis à nouveau la photo."
      )
    end

    # Le contenu du fichier n'a pas d'importance : le job ne fait que l'encoder
    # en base64 avant de le passer au service, ici simulé.
    def post_photo_import
      post recipe_imports_path, params: {
        source_type: "photo",
        photo_file: Rack::Test::UploadedFile.new(StringIO.new("photo"), "image/jpeg",
                                                 original_filename: "magazine.jpg")
      }
    end
  end

  describe "GET /recipe_imports/:id (page d'attente)" do
    it "fait patienter tant que le job travaille, et revient voir d'elle-même" do
      import = create(:recipe_import, user: admin)

      get recipe_import_path(import)

      expect(response).to have_http_status(:success)
      expect(response.body).to include("Lecture de la page…")
      expect(response.body).to include('data-controller="import-poller"')
    end

    # L'étape affichée se règle sur le temps écoulé, côté serveur : un minuteur
    # dans le navigateur repartirait de zéro à chaque vérification.
    it "annonce l'étape suivante quand l'attente se prolonge" do
      import = create(:recipe_import, user: admin, created_at: 20.seconds.ago)

      get recipe_import_path(import)

      expect(response.body).to include("Encore quelques secondes…")
    end

    it "ne laisse pas suivre l'import de quelqu'un d'autre" do
      autre = create(:recipe_import, user: create(:user, admin: true))

      get recipe_import_path(autre)

      expect(response).to have_http_status(:not_found)
    end
  end
end
