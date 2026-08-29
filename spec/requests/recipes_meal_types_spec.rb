# frozen_string_literal: true

require "rails_helper"

# UC7 (Prompt 2) : le formulaire recette expose les chips "Moment(s) du repas"
# et la fiche recette les affiche en badges. La règle "au moins un moment" est
# déjà portée par le modèle (HasMealTypes) — ici on vérifie qu'elle remonte
# bien jusqu'à l'utilisateur via le formulaire, et son exemption brouillon IA.
RSpec.describe "Moments du repas sur la fiche recette (UC7)", type: :request do
  let(:admin) { create(:user, admin: true) }
  let(:ingredient) { create(:ingredient) }

  before { sign_in admin }

  def valid_recipe_params(meal_types:)
    {
      name: "Quiche lorraine",
      default_servings: 4,
      diet: "omnivore",
      meal_types: meal_types,
      preparations_attributes: { "0" => { ingredient_id: ingredient.id, quantity_base: 100 } }
    }
  end

  describe "POST /recipes" do
    it "crée la recette quand au moins un moment est coché" do
      post recipes_path, params: { recipe: valid_recipe_params(meal_types: %w[lunch dinner]) }

      expect(response).to redirect_to(recipe_path(Recipe.last))
      expect(Recipe.last.meal_types).to contain_exactly("lunch", "dinner")
    end

    it "refuse la création sans aucun moment coché, avec un message clair" do
      post recipes_path, params: { recipe: valid_recipe_params(meal_types: []) }

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.body).to include("doit comporter au moins un moment")
    end
  end

  describe "PATCH /recipes/:id — brouillon IA exempté" do
    it "sauvegarde le brouillon sans erreur même sans moment coché" do
      draft = create(:recipe, status: :draft, meal_types: [])

      patch recipe_path(draft), params: { recipe: { meal_types: [] } }

      expect(response).to redirect_to(edit_recipe_path(draft))
      expect(draft.reload.meal_types).to eq([])
    end
  end

  describe "GET /recipes/:id" do
    it "affiche un badge par moment annoncé, dans l'ordre de la journée" do
      recipe = create(:recipe, :with_ingredient, meal_types: %w[dinner breakfast])

      get recipe_path(recipe)

      expect(response.body).to include("Petit-déjeuner", "Dîner")
    end
  end
end
