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

    # UC7, chapitre 4 : depuis un catalogue filtré par moment, l'ajout crée le
    # repas avec ce moment — la recette atterrit dans la bonne section — et le
    # toggle s'évalue dans ce moment seulement.
    context "depuis un catalogue filtré par moment" do
      let!(:draft) { create(:menu, user: user, status: :draft) }

      it "crée le repas avec le moment du contexte et le reconduit dans le bouton re-rendu" do
        post toggle_in_draft_recipe_path(recipe, meal_type: "snack"), as: :turbo_stream

        expect(draft.menu_recipes.sole).to have_attributes(recipe_id: recipe.id, meal_type: "snack")
        expect(response.body).to include(toggle_in_draft_recipe_path(recipe, meal_type: "snack"))
      end

      it "ajoute la même recette dans un second moment au lieu de la retirer" do
        create(:menu_recipe, menu: draft, recipe: recipe, meal_type: "dinner", position: 0)

        post toggle_in_draft_recipe_path(recipe, meal_type: "snack"), as: :turbo_stream

        expect(draft.menu_recipes.pluck(:meal_type)).to contain_exactly("dinner", "snack")
      end

      it "ne retire que l'exemplaire du moment du contexte" do
        create(:menu_recipe, menu: draft, recipe: recipe, meal_type: "dinner", position: 0)
        create(:menu_recipe, menu: draft, recipe: recipe, meal_type: "snack", position: 1)

        post toggle_in_draft_recipe_path(recipe, meal_type: "snack"), as: :turbo_stream

        expect(draft.menu_recipes.sole.meal_type).to eq("dinner")
      end

      it "ignore un moment hors vocabulaire (liste blanche)" do
        post toggle_in_draft_recipe_path(recipe, meal_type: "hacker"), as: :turbo_stream

        expect(draft.menu_recipes.sole.meal_type).to be_nil
      end
    end
  end

  # Croix des vignettes du rail : retrait d'un repas précis (MenuRecipe) sans
  # quitter le catalogue. La répétition étant permise, seul l'exemplaire cliqué
  # doit disparaître — jamais « la recette » dans son ensemble.
  describe "DELETE /recipes/draft_meals/:id" do
    before { sign_in user }

    let!(:draft) { create(:menu, user: user, status: :draft) }

    it "ne retire que le repas visé quand la recette occupe plusieurs moments" do
      dinner = create(:menu_recipe, menu: draft, recipe: recipe, meal_type: "dinner", position: 0)
      create(:menu_recipe, menu: draft, recipe: recipe, meal_type: "snack", position: 1)

      delete recipes_draft_meal_path(dinner), as: :turbo_stream

      expect(response).to have_http_status(:success)
      expect(draft.menu_recipes.sole.meal_type).to eq("snack")
    end

    it "remplace le rail et repasse le bouton de la carte en « Ajouter »" do
      meal = create(:menu_recipe, menu: draft, recipe: recipe)

      delete recipes_draft_meal_path(meal), as: :turbo_stream

      expect(response.body).to include(%(target="draft-rail"), %(target="draft-btn-#{recipe.id}"))
      expect(response.body).to include("Aucune recette dans le menu", "Ajouter au menu à valider")
      expect(response.body).to include("retirée du menu à valider (0 recettes)")
    end

    it "laisse le bouton en « Retirer » quand un autre exemplaire reste dans le contexte" do
      create(:menu_recipe, menu: draft, recipe: recipe, meal_type: "dinner", position: 0)
      snack = create(:menu_recipe, menu: draft, recipe: recipe, meal_type: "snack", position: 1)

      # Catalogue non filtré : l'exemplaire du dîner suffit à garder l'état « déjà ajoutée »
      delete recipes_draft_meal_path(snack), as: :turbo_stream

      expect(response.body).to include("Retirer du menu à valider")
    end

    it "reconduit le moment du contexte dans les fragments re-rendus" do
      meal = create(:menu_recipe, menu: draft, recipe: recipe, meal_type: "snack", position: 0)
      kept = create(:menu_recipe, menu: draft, recipe: recipe_with_ingredient("Tian de légumes"),
                                  meal_type: "snack", position: 1)

      delete recipes_draft_meal_path(meal, meal_type: "snack"), as: :turbo_stream

      # Bouton de la carte et croix restante continuent de viser le moment courant
      expect(response.body).to include(toggle_in_draft_recipe_path(recipe, meal_type: "snack"))
      expect(response.body).to include(recipes_draft_meal_path(kept, meal_type: "snack"))
    end

    it "refuse le repas d'un menu d'une autre utilisatrice (404)" do
      foreign_draft = create(:menu, user: create(:user), status: :draft)
      foreign_meal = create(:menu_recipe, menu: foreign_draft, recipe: recipe)

      delete recipes_draft_meal_path(foreign_meal), as: :turbo_stream

      expect(response).to have_http_status(:not_found)
      expect(foreign_draft.menu_recipes.count).to eq(1)
    end
  end

  describe "GET /recipes filtré par moment (UC7)" do
    before { sign_in user }

    it "n'affiche « déjà ajoutée » que dans le moment du filtre" do
      versatile = create(:recipe, :with_ingredient, name: "Cake salé", meal_types: %w[dinner snack])
      draft = create(:menu, user: user, status: :draft)
      create(:menu_recipe, menu: draft, recipe: versatile, meal_type: "dinner", position: 0)

      get recipes_path(meal_type: "dinner")
      expect(response.body).to include("Retirer des dîners du menu à valider")

      get recipes_path(meal_type: "snack")
      expect(response.body).to include("Ajouter aux goûters du menu à valider")
    end
  end
end
