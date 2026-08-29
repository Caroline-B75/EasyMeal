# frozen_string_literal: true

require "rails_helper"

# UC7, chapitre 2 — « On passe commande de sa semaine ».
# Le formulaire décrit une répartition par moment ; le contrôleur la mémorise,
# la rejoue et refuse une commande vide.
RSpec.describe "Génération de menu par répartition", type: :request do
  let(:user) { create(:user) }

  before { sign_in user }

  # Pool minimal : des recettes publiées (donc avec ingrédient et moment),
  # végétariennes par défaut — compatibles omnivore comme végétarien.
  def publish_recipes(count, meal_types: %w[lunch dinner])
    create_list(:recipe, count, :with_ingredient, meal_types: meal_types)
  end

  def draft
    user.menus.status_draft.first
  end

  describe "GET /menus/new" do
    it "pré-remplit le formulaire avec la semaine type mémorisée" do
      user.update!(default_meal_counts: { "breakfast" => 7, "lunch" => 2 })

      get new_menu_path

      expect(response).to have_http_status(:success)
      expect(response.body).to include("7 petits-déjs · 2 déjs")
      expect(response.body).to include('name="menu[meal_counts][breakfast]"')
    end

    it "ouvre sur une semaine vide tant que rien n'a été décrit" do
      get new_menu_path

      expect(response.body).to include(MenusHelper::NO_MEALS_SUMMARY)
      expect(response.body).to include("Choisis au moins un repas")
    end
  end

  describe "POST /menus" do
    it "génère la commande moment par moment et la mémorise sur le menu" do
      publish_recipes(2, meal_types: %w[breakfast])
      publish_recipes(3)

      post menus_path, params: { menu: { diet: "omnivore", default_people: 4,
                                         meal_counts: { breakfast: 2, dinner: 3 } } }

      expect(response).to redirect_to(draft)
      expect(draft.menu_recipes.for_meal("breakfast").count).to eq(2)
      expect(draft.menu_recipes.for_meal("dinner").count).to eq(3)
      expect(draft.requested_meal_counts).to eq({ "breakfast" => 2, "dinner" => 3 })
    end

    it "mémorise la répartition complète quand « Mémoriser » est coché" do
      publish_recipes(9)

      post menus_path, params: { menu: { diet: "vegetarien", default_people: 3,
                                         meal_counts: { breakfast: 7, lunch: 2, same_breakfast: "1" },
                                         save_as_defaults: "1" } }

      counts = user.reload.preferred_meal_counts
      expect(counts.to_h).to eq({ "breakfast" => 7, "lunch" => 2, "same_breakfast" => true })
      expect(counts.same_breakfast?).to be(true)
      expect(user.default_people).to eq(3)
      expect(user).to be_preferences_configured
    end

    it "ne mémorise rien quand la case est décochée" do
      publish_recipes(2)

      post menus_path, params: { menu: { diet: "omnivore", default_people: 4,
                                         meal_counts: { dinner: 2 } } }

      expect(user.reload.preferred_meal_counts.any?).to be(false)
    end

    it "refuse une commande sans le moindre repas" do
      publish_recipes(2)

      post menus_path, params: { menu: { diet: "omnivore", default_people: 4,
                                         meal_counts: { breakfast: 0 } } }

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.body).to include(MenusController::NO_MEALS_ALERT)
      expect(user.menus).to be_empty
    end

    context "depuis le bouton direct « Créer un menu »" do
      before { user.update!(preferences_configured: true) }

      it "rejoue la semaine type mémorisée" do
        publish_recipes(4)
        user.update!(default_meal_counts: { "lunch" => 2, "dinner" => 1 })

        post menus_path

        expect(draft.menu_recipes.count).to eq(3)
      end

      it "invite à décrire sa semaine si aucune répartition n'est mémorisée" do
        post menus_path

        expect(response).to redirect_to(new_menu_path)
        expect(flash[:notice]).to eq(MenusController::DESCRIBE_WEEK_NOTICE)
        expect(user.menus).to be_empty
      end
    end
  end

  describe "POST /menus/:id/regenerate" do
    let(:menu) { create(:menu, user: user, status: :draft, diet: :omnivore) }

    before do
      publish_recipes(3).each_with_index do |recipe, index|
        create(:menu_recipe, menu: menu, recipe: recipe, number_of_people: 4, position: index)
      end
    end

    it "honore la répartition transmise et en fait la nouvelle commande du menu" do
      post regenerate_menu_path(menu), params: { menu: { diet: "vegetarien",
                                                         meal_counts: { lunch: 2 } } }

      expect(response).to redirect_to(menu)
      expect(menu.reload.menu_recipes.count).to eq(2)
      expect(menu.menu_recipes.map(&:meal_type)).to all(eq("lunch"))
      expect(menu.diet).to eq("vegetarien")
      expect(menu.requested_meal_counts).to eq({ "lunch" => 2 })
    end

    it "rejoue la commande mémorisée quand rien n'est transmis (changement de régime du panneau)" do
      menu.update!(requested_meal_counts: { "lunch" => 1, "dinner" => 2 })

      post regenerate_menu_path(menu), params: { menu: { diet: "vegetarien" } }

      expect(response).to redirect_to(menu)
      meals = menu.reload.menu_recipes
      expect(meals.for_meal("lunch").count).to eq(1)
      expect(meals.for_meal("dinner").count).to eq(2)
      expect(menu.diet).to eq("vegetarien")
    end

    it "refuse une re-génération sans répartition transmise ni commande mémorisée" do
      post regenerate_menu_path(menu), params: { menu: { diet: "vegetarien" } }

      expect(response).to have_http_status(:unprocessable_entity)
      expect(menu.reload.menu_recipes.count).to eq(3)
      expect(menu.diet).to eq("omnivore")
    end
  end
end
