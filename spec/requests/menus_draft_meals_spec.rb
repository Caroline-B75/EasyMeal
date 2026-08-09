# frozen_string_literal: true

require "rails_helper"

# UC7, chapitre 4 — « Un brouillon qu'on range soi-même ».
# La vue brouillon présente ses repas dans UNE grille, sans titre de moment :
# la génération les range par moment, puis c'est l'utilisatrice qui annote les
# jours et réorganise les cartes. Les manques face à la commande tiennent en une
# ligne compacte, et une seule porte d'ajout subsiste : le catalogue.
RSpec.describe "Repas du brouillon", type: :request do
  let(:user) { create(:user) }
  let(:menu) { create(:menu, user: user, status: :draft) }

  before { sign_in user }

  # La factory recette porte un nom fixe : les tests qui lisent l'ordre
  # d'affichage doivent en passer un distinct (recipe_attrs).
  def add_meal(meal_type, position:, **recipe_attrs)
    recipe = create(:recipe, :with_ingredient, meal_types: [ meal_type || "lunch" ], **recipe_attrs)
    create(:menu_recipe, menu: menu, recipe: recipe, meal_type: meal_type, position: position)
  end

  describe "GET /menus/:id d'un brouillon" do
    it "ne titre plus aucun moment dans la grille : ni nom de section, ni compte face à la commande" do
      menu.update!(requested_meal_counts: { "breakfast" => 2, "dinner" => 2 })
      add_meal("breakfast", position: 0)
      add_meal("dinner",    position: 1)

      get menu_path(menu)

      expect(response).to have_http_status(:success)
      # Assertion portée au seul bloc des repas : le panneau de réglages, lui,
      # nomme bien les moments — ce sont ses steppers de répartition.
      grid = Nokogiri::HTML(response.body).at_css("#draft_meals").text
      expect(grid).not_to include("Petits-déjeuners", "Dîners", "(1/2)")
    end

    it "affiche les repas dans l'ordre des positions, sans regroupement par moment" do
      add_meal("dinner",    position: 0, name: "Un dîner placé en premier")
      add_meal("breakfast", position: 1, name: "Un petit-déjeuner placé ensuite")

      get menu_path(menu)

      expect(response.body.index("Un dîner placé en premier"))
        .to be < response.body.index("Un petit-déjeuner placé ensuite")
    end

    it "résume tous les manques en une ligne, sans renvoyer au catalogue" do
      menu.update!(requested_meal_counts: { "breakfast" => 1, "snack" => 3 })
      add_meal("snack", position: 0)

      get menu_path(menu)

      expect(response.body).to include("Il manque 1 petit-déjeuner, 2 goûters pour compléter ce menu.")
      expect(response.body).not_to include("depuis le catalogue !")
    end

    it "garde l'alerte des manques dans le DOM mais masquée quand la commande est honorée" do
      menu.update!(requested_meal_counts: { "dinner" => 1 })
      add_meal("dinner", position: 0)

      get menu_path(menu)

      expect(response.body).to include(%(id="draft_missing_meals"))
      expect(response.body).to include("hidden")
      expect(response.body).not_to include("Il manque")
    end

    it "n'offre qu'un seul bouton d'ajout, vers le catalogue non filtré" do
      add_meal("snack",  position: 0)
      add_meal("dinner", position: 1)

      get menu_path(menu)

      expect(response.body.scan("mc-add-btn").size).to eq(1)
      expect(response.body).not_to include(recipes_path(meal_type: "snack"))
    end

    it "n'offre plus d'ajout aléatoire" do
      add_meal("dinner", position: 0)

      get menu_path(menu)

      expect(response.body).not_to include("Repas aléatoire")
      expect(response.body).not_to include("add_random_meal")
    end
  end

  describe "POST /menus/:id/replace_meal (Turbo Stream)" do
    it "re-rend la seule carte remplacée, son état ⬆️/⬇️ relu depuis la base" do
      create(:recipe, :with_ingredient, name: "Le remplaçant", meal_types: %w[dinner])
      meal = add_meal("dinner", position: 0, name: "Le remplacé")
      add_meal("dinner", position: 1)

      post replace_meal_menu_path(menu), params: { menu_recipe_id: meal.id }, as: :turbo_stream

      expect(response).to have_http_status(:success)
      expect(response.body).to include("Le remplaçant")
      # Repas en tête de grille : « monter » désactivé, « descendre » actif.
      expect(response.body.scan(/mc-move-btn[^>]*disabled/).size).to eq(1)
    end
  end

  describe "DELETE /menus/:menu_id/menu_recipes/:id (Turbo Stream)" do
    it "re-rend le bloc des repas : le manque né du retrait s'affiche" do
      menu.update!(requested_meal_counts: { "dinner" => 1 })
      meal = add_meal("dinner", position: 0)

      delete menu_menu_recipe_path(menu, meal), as: :turbo_stream

      expect(response).to have_http_status(:success)
      expect(response.body).to include(%(target="draft_meals"))
      expect(response.body).to include("Il manque 1 dîner pour compléter ce menu.")
    end

    it "re-rend aussi le panneau de réglages : ses steppers suivent la grille" do
      meal = add_meal("dinner", position: 0)

      delete menu_menu_recipe_path(menu, meal), as: :turbo_stream

      expect(response.body).to include(%(target="menu_settings_#{menu.id}"))
    end
  end
end
