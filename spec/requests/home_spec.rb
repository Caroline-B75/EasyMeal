require 'rails_helper'

RSpec.describe "Homes", type: :request do
  describe "GET /index" do
    it "returns http success" do
      get "/home/index"
      expect(response).to have_http_status(:success)
    end

    # Le partial du menu actif portait un bloc « Prochain : … » adossé à
    # scheduled_date, colonne jamais alimentée et supprimée par UC7.
    it "affiche la carte du menu actif avec ses repas" do
      user = create(:user)
      menu = create(:menu, user: user, status: :active, name: "Menu de la semaine")
      recipe = create(:recipe, :with_ingredient, name: "Tarte aux poireaux")
      create(:menu_recipe, menu: menu, recipe: recipe)
      sign_in user

      get "/home/index"

      expect(response).to have_http_status(:success)
      expect(response.body).to include("Menu de la semaine", "Tarte aux poireaux")
    end
  end
end
