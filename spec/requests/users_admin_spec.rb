# frozen_string_literal: true

require "rails_helper"

# Les écrans d'administration exposent les préférences de génération : ils ont
# suivi le passage de « nombre de repas » à une répartition par moment (UC7).
RSpec.describe "Administration des utilisateurs", type: :request do
  let(:admin) { create(:user, admin: true) }

  before { sign_in admin }

  it "affiche le volume de la semaine type dans la liste" do
    create(:user, default_people: 4, default_meal_counts: { "lunch" => 2, "dinner" => 7 })

    get users_path

    expect(response).to have_http_status(:success)
    expect(response.body).to include("4 pers. · 9 repas")
  end

  it "affiche le formulaire d'édition d'un utilisateur" do
    get edit_user_path(create(:user))

    expect(response).to have_http_status(:success)
    expect(response.body).to include("Régime par défaut", "Personnes par repas")
  end
end
