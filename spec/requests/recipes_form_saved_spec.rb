# frozen_string_literal: true

require "rails_helper"

# form-recovery retient dans l'onglet la saisie du formulaire de recette. Seule
# la page qui suit une sauvegarde acceptée peut lui dire de l'oublier : sans ce
# signal, une nouvelle recette s'ouvrait remplie de la précédente. Le signal est
# le marqueur `form-saved`, posé une seule fois, et jamais comme message flash.
RSpec.describe "Oubli de la saisie après une sauvegarde de recette", type: :request do
  let(:admin) { create(:user, admin: true) }
  let(:ingredient) { create(:ingredient) }
  let(:marker) { 'data-controller="form-saved"' }

  before { sign_in admin }

  def recipe_params(name: "Quiche lorraine")
    {
      name: name,
      default_servings: 4,
      diet: "omnivore",
      meal_types: %w[lunch],
      preparations_attributes: { "0" => { ingredient_id: ingredient.id, quantity_base: 100 } }
    }
  end

  it "pose le marqueur sur la fiche qui suit une création, une seule fois" do
    post recipes_path, params: { recipe: recipe_params }
    follow_redirect!

    expect(response.body).to include(marker)
    expect(response.body).not_to include("flash-message form_saved")

    get new_recipe_path

    expect(response.body).not_to include(marker)
  end

  it "pose le marqueur sur le formulaire qui suit un brouillon sauvegardé" do
    draft = create(:recipe, status: :draft, meal_types: [])

    patch recipe_path(draft), params: { recipe: { name: "Brouillon renommé" } }
    follow_redirect!

    expect(response.body).to include(marker)
  end

  it "ne pose rien quand la sauvegarde est refusée" do
    post recipes_path, params: { recipe: recipe_params(name: "") }

    expect(response).to have_http_status(:unprocessable_entity)
    expect(response.body).not_to include(marker)
  end
end
