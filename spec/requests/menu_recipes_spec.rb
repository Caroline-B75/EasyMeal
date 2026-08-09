# frozen_string_literal: true

require "rails_helper"

# UC7, chapitre 4 — « Les cartes de repas s'enrichissent aussi » : badge temps,
# moment et jour du repas (le jour teinte la carte, sans jamais la déplacer) et
# réordonnancement mobile ⬆️/⬇️ dans une grille unique.
RSpec.describe "Repas d'un menu (MenuRecipe)", type: :request do
  let(:user) { create(:user) }
  let(:menu) { create(:menu, user: user, status: :draft) }

  before { sign_in user }

  def add_meal(meal_type, position:, **recipe_attrs)
    recipe = create(:recipe, :with_ingredient, meal_types: [ meal_type || "lunch" ], **recipe_attrs)
    create(:menu_recipe, menu: menu, recipe: recipe, meal_type: meal_type, position: position)
  end

  describe "GET /menus/:id — carte enrichie (UC7)" do
    it "affiche le badge temps quand la recette en a un" do
      add_meal("dinner", position: 0, prep_time_minutes: 10, cook_time_minutes: 25)

      get menu_path(menu)

      expect(response.body).to include("35 min")
    end

    it "n'affiche aucun badge temps quand la recette n'a aucun temps renseigné" do
      add_meal("dinner", position: 0, prep_time_minutes: nil, cook_time_minutes: nil)

      get menu_path(menu)

      expect(response.body).not_to include("mc-card-time-badge")
    end

    it "teinte la carte du jour annoté" do
      meal = add_meal("dinner", position: 0)
      meal.update!(day_of_week: 2)

      get menu_path(menu)

      expect(response.body).to include('data-day="2"')
    end

    it "propose les jours en diminutif et les moments en libellé compact" do
      add_meal("breakfast", position: 0)

      get menu_path(menu)

      expect(response.body).to include(">Lun<", ">Dim<", ">Petit-déj<")
      expect(response.body).not_to include(">Petit-déjeuner<")
    end

    it "photo et nom ouvrent la recette, hors de la turbo-frame et sans gêner le drag" do
      meal = add_meal("dinner", position: 0)

      get menu_path(menu)

      expect(response.body).to include(%(href="#{recipe_path(meal.recipe)}"))
      expect(response.body).to include(%(data-turbo-frame="_top"))
      expect(response.body).to include(%(draggable="false"))
    end
  end

  describe "PATCH /menus/:menu_id/menu_recipes/:id" do
    # Chaque champ de la carte est piloté par un <select> qui vit DANS la carte :
    # tout ce qu'on re-rend détruit le <select> que l'utilisatrice vient
    # d'actionner (focus perdu, défilement de la page qui saute). La réponse est
    # donc taillée sur ce qui bouge vraiment à l'écran, et rien de plus.
    it "change le nombre de personnes sans rien re-rendre : le <select> porte déjà la valeur" do
      meal = add_meal("dinner", position: 0)

      patch menu_menu_recipe_path(menu, meal), params: { menu_recipe: { number_of_people: 6 } }, as: :turbo_stream

      expect(response).to have_http_status(:no_content)
      expect(meal.reload.number_of_people).to eq(6)
      expect(response.body).to be_empty
    end

    it "renseigne le jour sans rien re-rendre : la teinte est posée côté client" do
      meal = add_meal("dinner", position: 0)

      patch menu_menu_recipe_path(menu, meal), params: { menu_recipe: { day_of_week: 2 } }, as: :turbo_stream

      expect(response).to have_http_status(:no_content)
      expect(meal.reload.day_of_week).to eq(2)
      expect(response.body).to be_empty
    end

    it "change le moment : la carte ne bouge pas, seule l'alerte des manques est re-rendue" do
      menu.update!(requested_meal_counts: { "lunch" => 1 })
      meal = add_meal("lunch", position: 0)

      patch menu_menu_recipe_path(menu, meal), params: { menu_recipe: { meal_type: "dinner" } }, as: :turbo_stream

      expect(response).to have_http_status(:success)
      expect(meal.reload.meal_type).to eq("dinner")
      expect(response.body).to include(%(target="draft_missing_meals"))
      expect(response.body).to include("Il manque 1 déjeuner pour compléter ce menu.")
      expect(response.body).not_to include(%(id="menu_recipe_#{meal.id}"))
    end
  end

  # UC3 — le menu validé garde une grille vivante : le jour (pure annotation,
  # sans effet sur la liste de courses) et l'ordre des cartes restent à la main
  # de l'utilisatrice ; moment et personnes, eux, engagent la liste validée.
  describe "menu actif — jour et ordre restent modifiables" do
    let(:menu) { create(:menu, user: user, status: :active) }

    it "garde badge temps, sélecteur de jour et ⬆️/⬇️, mais fige moment et personnes" do
      add_meal("dinner", position: 0, prep_time_minutes: 10, cook_time_minutes: 25)

      get menu_path(menu)

      expect(response.body).to include("35 min")
      expect(response.body).to include("menu_recipe[day_of_week]")
      expect(response.body).to include("mc-move-btn")
      expect(response.body).not_to include("menu_recipe[meal_type]")
      expect(response.body).not_to include("menu_recipe[number_of_people]")
    end

    it "renseigne le jour sans rien re-rendre, comme sur le brouillon" do
      meal = add_meal("dinner", position: 0)

      patch menu_menu_recipe_path(menu, meal), params: { menu_recipe: { day_of_week: 4 } }, as: :turbo_stream

      expect(response).to have_http_status(:no_content)
      expect(meal.reload.day_of_week).to eq(4)
    end

    it "refuse de toucher aux personnes et au moment, même en requête forgée" do
      meal = add_meal("dinner", position: 0)

      expect {
        patch menu_menu_recipe_path(menu, meal),
              params: { menu_recipe: { number_of_people: 9, meal_type: "breakfast", day_of_week: 4 } },
              as: :turbo_stream
      }.not_to change { meal.reload.slice(:number_of_people, :meal_type) }

      expect(meal.day_of_week).to eq(4)
    end

    it "réordonne ⬆️/⬇️ en re-rendant le bloc des repas actif" do
      first  = add_meal("dinner", position: 0)
      second = add_meal("dinner", position: 1)

      patch move_up_menu_menu_recipe_path(menu, second), as: :turbo_stream

      expect(response).to have_http_status(:success)
      expect(response.body).to include(%(target="active_meals"))
      expect(first.reload.position).to eq(1)
      expect(second.reload.position).to eq(0)
    end

    it "persiste l'ordre du drag & drop" do
      first  = add_meal("dinner", position: 0)
      second = add_meal("dinner", position: 1)

      patch reorder_menu_menu_recipes_path(menu), params: { ids: [ second.id, first.id ] }, as: :json

      expect(response).to have_http_status(:ok)
      expect(second.reload.position).to eq(0)
      expect(first.reload.position).to eq(1)
    end
  end

  describe "PATCH /menus/:menu_id/menu_recipes/:id/move_up et move_down" do
    it "monter échange la position avec le repas du dessus" do
      first  = add_meal("dinner", position: 0)
      second = add_meal("dinner", position: 1)

      patch move_up_menu_menu_recipe_path(menu, second), as: :turbo_stream

      expect(response).to have_http_status(:success)
      expect(response.body).to include(%(target="draft_meals"))
      expect(first.reload.position).to eq(1)
      expect(second.reload.position).to eq(0)
    end

    it "descendre échange la position avec le repas du dessous" do
      first  = add_meal("dinner", position: 0)
      second = add_meal("dinner", position: 1)

      patch move_down_menu_menu_recipe_path(menu, first), as: :turbo_stream

      expect(first.reload.position).to eq(1)
      expect(second.reload.position).to eq(0)
    end

    it "ne fait rien en tête de grille" do
      first = add_meal("dinner", position: 0)
      add_meal("dinner", position: 1)

      expect {
        patch move_up_menu_menu_recipe_path(menu, first), as: :turbo_stream
      }.not_to change { first.reload.position }
    end

    it "ne fait rien en fin de grille" do
      add_meal("dinner", position: 0)
      last = add_meal("dinner", position: 1)

      expect {
        patch move_down_menu_menu_recipe_path(menu, last), as: :turbo_stream
      }.not_to change { last.reload.position }
    end

    it "franchit les moments : l'ordre de la grille appartient à l'utilisatrice" do
      breakfast = add_meal("breakfast", position: 0)
      dinner    = add_meal("dinner", position: 1)

      patch move_down_menu_menu_recipe_path(menu, breakfast), as: :turbo_stream

      expect(breakfast.reload.position).to eq(1)
      expect(dinner.reload.position).to eq(0)
    end
  end
end
