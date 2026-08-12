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
  describe "GET /ingredients/search" do
    it "renvoie les ingrédients correspondants avec la route d'apprentissage de l'alias" do
      # Le poids unitaire fait partie du contrat : c'est lui qui permet au
      # panneau de convertir « 2 tranches » avant de poser la ligne.
      thym = create(:ingredient, name: "Thym frais", piece_weight_g: 2)
      create(:ingredient, name: "Persil")

      get search_ingredients_path(q: "thym")

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to eq([
        { "id" => thym.id, "name" => "Thym frais", "base_unit" => "g",
          "unit_group" => "mass", "piece_weight_g" => "2.0",
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
