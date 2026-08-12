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
      # L'action proposée suit le statut : il reste des champs à saisir
      expect(response.body).to include(">Compléter</a>")
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
      # Plus rien à saisir : l'action proposée est la validation
      expect(response.body).to include(">Valider</a>")
    end

    it "rend le badge d'un import par lien cliquable vers la page d'origine" do
      create(:recipe,
             status: :draft,
             source_type: "url",
             source_url: "https://exemple.test/tarte-aux-pommes")

      get recipe_drafts_path

      expect(response.body).to include("badge--source-link")
      expect(response.body).to include('href="https://exemple.test/tarte-aux-pommes"')
      expect(response.body).to include('target="_blank"')
      expect(response.body).to include('rel="noopener noreferrer"')
    end

    it "laisse le badge d'un import photo non cliquable" do
      create(:recipe, status: :draft, source_type: "photo", source_url: nil)

      get recipe_drafts_path

      expect(response.body).to include("badge--source")
      expect(response.body).not_to include("badge--source-link")
    end

    # Vieil import par lien dont l'URL d'origine n'a pas été conservée : le badge
    # doit rester un simple libellé plutôt qu'un lien vers nulle part.
    it "laisse le badge d'un import par lien sans source_url non cliquable" do
      create(:recipe, status: :draft, source_type: "url", source_url: nil)

      get recipe_drafts_path

      expect(response.body).to include("badge--source")
      expect(response.body).not_to include("badge--source-link")
    end
  end

  # Une paire qui oppose les deux axes de tri : le brouillon complet est le plus
  # ancien, l'incomplet le plus récent. Chaque critère doit donc les inverser.
  describe "GET /recipe_drafts — tri de la liste" do
    let!(:ancien_complet) do
      recipe = create(:recipe, status: :draft, name: "Quiche prête",
                               instructions: "Cuire 30 min.", created_at: 3.days.ago)
      create(:preparation, recipe: recipe, ingredient: create(:ingredient))
      recipe
    end

    let!(:recent_incomplet) do
      create(:recipe, status: :draft, name: "Gratin à finir",
                      instructions: nil, created_at: 1.hour.ago)
    end

    # L'ordre du HTML est l'ordre affiché : comparer les positions suffit.
    def position_of(name)
      response.body.index(name)
    end

    it "classe du plus récent au plus ancien par défaut" do
      get recipe_drafts_path

      expect(position_of("Gratin à finir")).to be < position_of("Quiche prête")
      # Le sélecteur pilote bien le paramètre lu par le contrôleur, et propose
      # les deux axes (date, statut). Libellés tronqués avant l'apostrophe :
      # options_for_select l'échappe en &#39;.
      expect(response.body).to include('name="sort"', "Plus récentes", "Prêtes à valider")
    end

    it "classe du plus ancien au plus récent sur demande" do
      get recipe_drafts_path(sort: "oldest")

      expect(position_of("Quiche prête")).to be < position_of("Gratin à finir")
    end

    it "remonte les brouillons prêts à valider, malgré leur ancienneté" do
      get recipe_drafts_path(sort: "ready")

      expect(position_of("Quiche prête")).to be < position_of("Gratin à finir")
    end

    it "remonte les brouillons à compléter" do
      get recipe_drafts_path(sort: "todo")

      expect(position_of("Gratin à finir")).to be < position_of("Quiche prête")
    end

    # Un paramètre trafiqué ne doit ni faire planter la page ni laisser passer
    # une clé d'ordre arbitraire vers la requête SQL.
    it "retombe sur le tri par défaut quand le critère est inconnu" do
      get recipe_drafts_path(sort: "created_at asc; DROP TABLE recipes")

      expect(response).to have_http_status(:ok)
      expect(position_of("Gratin à finir")).to be < position_of("Quiche prête")
    end
  end

  describe "DELETE /recipe_drafts/:id" do
    it "supprime le brouillon et ramène à la liste des imports" do
      draft = create(:recipe, status: :draft)

      expect { delete recipe_draft_path(draft) }.to change(Recipe, :count).by(-1)

      expect(response).to redirect_to(recipe_drafts_path)
      expect(flash[:notice]).to eq("Brouillon supprimé.")
    end

    # La route ne voit que les brouillons (Recipe.draft.find) : une recette
    # publiée n'est pas supprimable par ce chemin, même par un admin.
    it "refuse de supprimer une recette publiée" do
      published = create(:recipe, :with_ingredient)

      expect { delete recipe_draft_path(published) }.not_to change(Recipe, :count)
      expect(response).to have_http_status(:not_found)
    end

    it "refuse la suppression à un utilisateur non admin" do
      draft = create(:recipe, status: :draft)
      sign_in create(:user)

      expect { delete recipe_draft_path(draft) }.not_to change(Recipe, :count)
      expect(flash[:alert]).to eq("Tu n'es pas autorisé(e) à effectuer cette action.")
    end
  end
end
