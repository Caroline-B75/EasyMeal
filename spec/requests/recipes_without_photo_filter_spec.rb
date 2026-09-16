# frozen_string_literal: true

require "rails_helper"

# Filtre de travail sans bouton dans l'interface : /recipes?photo=false liste
# les recettes du catalogue encore affichées avec la photo par défaut, pour
# que l'admin sache lesquelles illustrer.
RSpec.describe "Filtre des recettes sans photo", type: :request do
  let!(:with_photo)        { create(:recipe, :with_ingredient, :with_photo, name: "Tarte illustrée") }
  let!(:without_photo)     { create(:recipe, :with_ingredient, name: "Quiche sans photo") }
  # Seule la photo du plat compte : la page d'origine d'un import ne remplace
  # pas la photo par défaut sur la carte du catalogue.
  let!(:only_source_photo) { create(:recipe, :with_ingredient, :with_source_photo, name: "Soupe importée") }

  context "pour un admin" do
    before { sign_in create(:user, admin: true) }

    it "ne garde que les recettes sans photo du plat" do
      get recipes_path(photo: "false")

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Quiche sans photo", "Soupe importée")
      expect(response.body).not_to include("Tarte illustrée")
    end

    it "se combine avec les autres filtres du catalogue" do
      get recipes_path(photo: "false", query: "quiche")

      expect(response.body).to include("Quiche sans photo")
      expect(response.body).not_to include("Soupe importée", "Tarte illustrée")
    end

    it "reste inactif sans le paramètre" do
      get recipes_path

      expect(response.body).to include("Tarte illustrée", "Quiche sans photo")
    end
  end

  context "pour un utilisateur non admin" do
    before { sign_in create(:user) }

    it "ignore le paramètre" do
      get recipes_path(photo: "false")

      expect(response.body).to include("Tarte illustrée", "Quiche sans photo")
    end
  end

  context "pour un visiteur déconnecté" do
    it "ignore le paramètre" do
      get recipes_path(photo: "false")

      expect(response.body).to include("Tarte illustrée", "Quiche sans photo")
    end
  end
end
