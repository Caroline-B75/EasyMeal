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
end
