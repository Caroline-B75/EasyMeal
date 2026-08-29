# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Ingredients", type: :request do
  let(:user) { create(:user) }

  before { sign_in user }

  describe "GET /ingredients" do
    it "affiche chaque ingrédient avec son rayon en français et sa couleur de rayon" do
      create(:ingredient, name: "Tomate", category: :fruits_legumes)

      get ingredients_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Fruits et légumes")
      # data-category porte la couleur du rayon (palette partagée avec la liste de courses)
      expect(response.body).to include('data-category="fruits_legumes"')
    end

    it "affiche les mois de saison en français" do
      create(:ingredient, name: "Courge", season_months: [ 2 ])

      get ingredients_path

      expect(response.body).to include("fév.")
    end

    # Le formulaire n'a plus de bouton d'envoi : les filtres partent tout seuls
    # (contrôleur Stimulus filter-form), le lien d'effacement n'apparaît qu'utile.
    it "propose des filtres auto-soumis, sans bouton de recherche" do
      get ingredients_path

      expect(response.body).to include('data-controller="filter-form"')
      expect(response.body).not_to include('type="submit"')
      expect(response.body).to include("btn btn-link hidden")
    end

    it "démasque le lien d'effacement dès qu'un filtre est posé" do
      get ingredients_path(category: "fruits_legumes")

      expect(response.body).to include("Effacer les filtres")
      expect(response.body).not_to include("btn btn-link hidden")
    end

    it "filtre par rayon" do
      create(:ingredient, name: "Tomate", category: :fruits_legumes)
      create(:ingredient, name: "Sel", category: :epicerie_salee)

      get ingredients_path(category: "fruits_legumes")

      expect(response.body).to include("Tomate")
      expect(response.body).not_to include("Sel")
    end

    it "filtre par nom" do
      create(:ingredient, name: "Tomate")
      create(:ingredient, name: "Carotte")

      get ingredients_path(query: "tom")

      expect(response.body).to include("Tomate")
      expect(response.body).not_to include("Carotte")
    end

    it "filtre par mois de saison" do
      create(:ingredient, name: "Tomate", season_months: [ 7, 8 ])
      create(:ingredient, name: "Courge", season_months: [ 10, 11 ])

      get ingredients_path(month: 7)

      expect(response.body).to include("Tomate")
      expect(response.body).not_to include("Courge")
    end
  end

  # Recherche JSON du panneau IA : associer une ligne détectée à un ingrédient
  # existant plutôt que d'en créer un doublon.
  # Une densité estimée par l'IA pèse sur les quantités de la liste de courses :
  # elle se signale dans le catalogue, et se retrouve d'un filtre.
  describe "GET /ingredients — densités à vérifier" do
    let!(:estimee) do
      create(:ingredient, name: "Tahini", unit_group: :spoon, base_unit: "cac",
                          density_g_per_ml: 1.05, density_source: :ai)
    end
    let!(:verifiee) do
      create(:ingredient, name: "Farine", unit_group: :mass, base_unit: "g",
                          density_g_per_ml: 0.55, density_source: :manual)
    end

    it "signale d'une pastille les densités estimées, et elles seules" do
      get ingredients_path

      expect(response.body).to include("densité à vérifier")
      expect(response.body).to include(ERB::Util.html_escape(I18n.t("ingredients.density_to_check")))
      # Une seule pastille : celle de l'ingrédient estimé
      expect(response.body.scan("densité à vérifier").size).to eq(1)
    end

    it "les rassemble sur demande" do
      get ingredients_path(to_check: "true")

      expect(response.body).to include(estimee.name)
      expect(response.body).not_to include(verifiee.name)
    end

    it "compte ce filtre parmi ceux qu'on peut effacer" do
      get ingredients_path(to_check: "true")

      expect(response.body).to include("Effacer les filtres")
      expect(response.body).not_to match(/btn btn-link hidden[^>]*>\s*Effacer/)
    end
  end

  # Le formulaire est le seul chemin par lequel une densité devient « vérifiée ».
  describe "PATCH /ingredients/:id — vérification d'une densité" do
    let(:admin) { create(:user, admin: true) }
    let(:farine) do
      create(:ingredient, name: "Farine", unit_group: :mass, base_unit: "g",
                          density_g_per_ml: 0.55, density_source: :ai)
    end

    before { sign_in admin }

    it "propose le champ de densité et rappelle qu'elle est à vérifier" do
      get edit_ingredient_path(farine)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Densité (g/ml)")
      expect(response.body).to include(ERB::Util.html_escape(I18n.t("ingredients.density_to_check")))
    end

    it "montre les coefficients de conversion sur la fiche" do
      get ingredient_path(farine)

      expect(response.body).to include("Conversions", "0,55 g/ml")
    end

    it "tient une densité enregistrée par un humain pour vérifiée" do
      patch ingredient_path(farine), params: { ingredient: { density_g_per_ml: "0.6" } }

      expect(farine.reload).to have_attributes(density_g_per_ml: 0.6, density_source: "manual")
    end

    # Même sans correction : avoir lu la valeur et enregistré vaut vérification.
    it "vaut vérification même quand la valeur ne change pas" do
      patch ingredient_path(farine), params: { ingredient: { density_g_per_ml: "0.55" } }

      expect(farine.reload.density_source).to eq("manual")
    end

    it "efface la provenance avec la densité" do
      patch ingredient_path(farine), params: { ingredient: { density_g_per_ml: "" } }

      expect(farine.reload).to have_attributes(density_g_per_ml: nil, density_source: nil)
    end

    # Un formulaire qui ne parle pas de densité ne doit pas en changer la
    # provenance : l'ajout d'un alias n'est pas une vérification.
    it "laisse la provenance intacte quand le formulaire ne porte pas la densité" do
      patch ingredient_path(farine), params: { ingredient: { name: "Farine T55" } }

      expect(farine.reload).to have_attributes(name: "Farine T55", density_source: "ai")
    end
  end

  describe "GET /ingredients/search" do
    it "renvoie les ingrédients correspondants avec la route d'apprentissage de l'alias" do
      # Les deux coefficients de conversion font partie du contrat : ce sont eux
      # qui permettent au panneau de convertir « 2 tranches » ou « 1 càs » avant
      # de poser la ligne, et la provenance de la densité de signaler une
      # estimation.
      thym = create(:ingredient, name: "Thym frais", piece_weight_g: 2,
                                 density_g_per_ml: 0.4, density_source: :ai)
      create(:ingredient, name: "Persil")

      get search_ingredients_path(q: "thym")

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to eq([
        { "id" => thym.id, "name" => "Thym frais", "base_unit" => "g",
          "unit_group" => "mass", "piece_weight_g" => "2.0",
          "density_g_per_ml" => "0.4", "density_source" => "ai",
          "add_alias_path" => add_alias_ingredient_path(thym) }
      ])
    end

    # Même réduction que le matcher : taper le nom détecté par l'IA tel quel
    # doit ramener l'ingrédient, sans quoi la recherche manuelle échouerait
    # exactement là où la détection automatique a échoué.
    it "retire le quantificateur de la requête" do
      create(:ingredient, name: "Thym frais")

      get search_ingredients_path(q: "Brin de thym")

      expect(response.parsed_body.map { |i| i["name"] }).to eq([ "Thym frais" ])
    end

    it "cherche aussi dans les alias" do
      create(:ingredient, name: "Thym frais", aliases: [ "farigoule" ])

      get search_ingredients_path(q: "farigoule")

      expect(response.parsed_body.map { |i| i["name"] }).to eq([ "Thym frais (farigoule)" ])
    end

    it "ne renvoie rien quand aucun ingrédient ne correspond" do
      create(:ingredient, name: "Persil")

      get search_ingredients_path(q: "boulgour")

      expect(response.parsed_body).to be_empty
    end
  end

  describe "PATCH /ingredients/:id/add_alias" do
    let(:admin) { create(:user, admin: true) }
    let(:thym)  { create(:ingredient, name: "Thym frais") }

    before { sign_in admin }

    # Le geste manuel du panneau IA ne vaut que s'il est relu : après avoir
    # associé « brin de thym » à Thym frais, l'import suivant doit le retrouver
    # seul, sans reposer la question.
    it "mémorise l'alias et le rend exploitable par la détection" do
      patch add_alias_ingredient_path(thym), params: { alias: "Brin de thym" }

      expect(response).to have_http_status(:ok)
      expect(thym.reload.aliases).to eq([ "brin de thym" ])
      expect(IngredientMatcherService.match("Brin de thym")[:exact]).to eq(thym)
    end

    it "n'enregistre pas deux fois le même alias" do
      thym.update!(aliases: [ "brin de thym" ])

      patch add_alias_ingredient_path(thym), params: { alias: "brin de thym" }

      expect(thym.reload.aliases).to eq([ "brin de thym" ])
    end

    # Sinon la détection aurait deux ingrédients à proposer pour un seul nom.
    it "n'apprend pas un alias qui est déjà le nom d'un autre ingrédient" do
      autre = create(:ingredient, name: "Thym séché")

      patch add_alias_ingredient_path(thym), params: { alias: "Thym séché" }

      expect(response).to have_http_status(:ok)
      expect(thym.reload.aliases).to be_blank
      expect(IngredientMatcherService.match("Thym séché")[:exact]).to eq(autre)
    end

    it "refuse un alias vide" do
      patch add_alias_ingredient_path(thym), params: { alias: "  " }

      expect(response).to have_http_status(:bad_request)
      expect(thym.reload.aliases).to be_blank
    end
  end
end
