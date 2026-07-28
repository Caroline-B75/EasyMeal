# frozen_string_literal: true

require "rails_helper"

# Rail « menu à valider » du catalogue (UC2 / UC5) : le menu en cours de
# composition reste visible pendant la recherche, et chaque ajout / retrait ne
# remplace que ce fragment via Turbo Stream.
RSpec.describe "Rail menu à valider du catalogue", type: :request do
  let(:user) { create(:user) }
  let(:recipe) { recipe_with_ingredient("Curry de lentilles") }

  # Une recette publiée exige au moins un ingrédient (validation Recipe)
  def recipe_with_ingredient(name)
    build(:recipe, name: name).tap do |r|
      r.preparations.build(ingredient: create(:ingredient), quantity_base: 100)
      r.save!
    end
  end

  describe "GET /recipes" do
    it "n'affiche ni rail ni invitation à créer un menu pour un visiteur non connecté" do
      recipe

      get recipes_path

      expect(response).to have_http_status(:success)
      expect(response.body).not_to include("draft-rail")
      expect(response.body).not_to include("Créer un menu")
    end

    context "connecté sans menu à valider" do
      before { sign_in user }

      it "propose de créer un menu depuis l'en-tête, sans afficher la colonne" do
        get recipes_path

        expect(response.body).to include("Créer un menu")
        expect(response.body).not_to include("draft-rail")
      end
    end

    context "connecté avec un menu à valider" do
      before { sign_in user }

      it "affiche le compteur, la vignette de chaque recette et l'accès au menu" do
        draft = create(:menu, user: user, status: :draft, name: "Semaine du 3")
        create(:menu_recipe, menu: draft, recipe: recipe)

        get recipes_path

        expect(response.body).to include("1 recette dans le menu", "Voir le menu")
        # Noms complets en infobulle : recette sur la vignette, menu sur l'action
        expect(response.body).to include(%(title="#{recipe.name}"), %(title="Semaine du 3"))
      end

      it "accorde le compteur au pluriel" do
        draft = create(:menu, user: user, status: :draft)
        create(:menu_recipe, menu: draft, recipe: recipe)
        create(:menu_recipe, menu: draft, recipe: recipe_with_ingredient("Tian de légumes"))

        get recipes_path

        expect(response.body).to include("2 recettes dans le menu")
      end

      it "signale un brouillon encore vide" do
        create(:menu, user: user, status: :draft)

        get recipes_path

        expect(response.body).to include("Aucune recette dans le menu", "Voir le menu")
        # Le brouillon existe : l'invitation de l'en-tête n'a plus lieu d'être
        expect(response.body).not_to include("Créer un menu")
      end
    end
  end

  describe "POST /recipes/:id/toggle_in_draft" do
    before { sign_in user }

    it "remplace le rail sans recharger les résultats" do
      post toggle_in_draft_recipe_path(recipe), as: :turbo_stream

      expect(response).to have_http_status(:success)
      expect(response.body).to include(%(target="draft-rail"), "1 recette dans le menu")
      expect(response.body).not_to include("recipes_list")
    end

    it "démarre un brouillon à la volée depuis la fiche recette (« Démarrer un menu »)" do
      expect(user.menus.status_draft).to be_empty

      post toggle_in_draft_recipe_path(recipe), as: :turbo_stream

      expect(user.menus.status_draft.count).to eq(1)
      expect(response.body).to include('class="draft-rail"', "1 recette dans le menu")
    end

    it "remet le rail à l'état vide au retrait de la dernière recette" do
      draft = create(:menu, user: user, status: :draft)
      create(:menu_recipe, menu: draft, recipe: recipe)

      post toggle_in_draft_recipe_path(recipe), as: :turbo_stream

      expect(response.body).to include("Aucune recette dans le menu")
    end
  end
end
