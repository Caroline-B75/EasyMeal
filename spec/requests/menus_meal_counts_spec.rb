# frozen_string_literal: true

require "rails_helper"

# UC7 — le panneau de réglages du brouillon dose les moments : un stepper par
# moment de la journée, qui agit directement sur la composition du menu.
RSpec.describe "Répartition des repas du brouillon", type: :request do
  let(:user) { create(:user) }
  let(:menu) { create(:menu, user: user, diet: :omnivore, default_people: 4) }

  before { sign_in user }

  def publish(meal_types:)
    create(:recipe, :with_ingredient, meal_types: meal_types)
  end

  def add_meal(meal_type, **attributes)
    create(:menu_recipe, { menu: menu, recipe: publish(meal_types: [ meal_type || "lunch" ]),
                           meal_type: meal_type, number_of_people: 4,
                           position: menu.menu_recipes.count }.merge(attributes))
  end

  # Le panneau de réglages de la dernière réponse rendue.
  def settings_panel
    Nokogiri::HTML(response.body).at_css("#menu_settings_#{menu.id}")
  end

  describe "GET /menus/:id d'un brouillon" do
    it "montre un stepper par moment, chiffré sur ce que la grille contient" do
      add_meal("dinner")
      add_meal("dinner")

      get menu_path(menu)

      steppers = settings_panel.css("[role='group']").to_h do |group|
        [ group["aria-label"], group.at_css(".mc-stepper-val").text ]
      end
      expect(steppers).to eq("Petits-déjeuners" => "0", "Déjeuners" => "0", "Goûters" => "0",
                             "Apéros" => "0", "Dîners" => "2")
    end

    it "désactive le « − » d'un moment absent du menu, jamais le « + »" do
      add_meal("dinner")

      get menu_path(menu)

      breakfast = settings_panel.at_css("[aria-label='Petits-déjeuners']")
      expect(breakfast.at_css("[value='-1']")[:disabled]).to be_present
      expect(breakfast.at_css("[value='1']")[:disabled]).to be_nil
    end

    it "compte les repas sans moment au déjeuner, comme leur carte les affiche" do
      add_meal(nil)

      get menu_path(menu)

      expect(settings_panel.at_css("[aria-label='Déjeuners'] .mc-stepper-val").text).to eq("1")
    end
  end

  describe "PATCH /menus/:id/adjust_meal_count (Turbo Stream)" do
    it "ajoute un repas du moment demandé et re-rend grille et réglages" do
      wanted = publish(meal_types: %w[snack])

      patch adjust_meal_count_menu_path(menu),
            params: { meal_type: "snack", delta: 1 }, as: :turbo_stream

      expect(response).to have_http_status(:success)
      expect(menu.menu_recipes.for_meal("snack").map(&:recipe)).to eq([ wanted ])
      expect(response.body).to include(%(target="draft_meals"), %(target="menu_settings_#{menu.id}"))
    end

    it "retire le dernier repas du moment et met la commande à jour" do
      menu.update!(requested_meal_counts: { "dinner" => 2 })
      kept = add_meal("dinner")
      last = add_meal("dinner")

      patch adjust_meal_count_menu_path(menu),
            params: { meal_type: "dinner", delta: -1 }, as: :turbo_stream

      expect(menu.menu_recipes.reload).to eq([ kept ])
      expect(MenuRecipe.exists?(last.id)).to be(false)
      expect(response.body).not_to include("Il manque")
    end

    it "dit pourquoi rien ne bouge quand le pool du moment est épuisé" do
      add_meal("dinner")

      expect {
        patch adjust_meal_count_menu_path(menu),
              params: { meal_type: "dinner", delta: 1 }, as: :turbo_stream
      }.not_to change { menu.menu_recipes.count }

      expect(response.body).to include("Plus aucune nouvelle recette de dîner disponible pour ce menu.")
    end

    it "refuse un moment hors du vocabulaire partagé" do
      patch adjust_meal_count_menu_path(menu),
            params: { meal_type: "brunch", delta: 1 }, as: :turbo_stream

      expect(response).to have_http_status(:bad_request)
    end

    it "refuse d'ajuster le menu de quelqu'un d'autre" do
      other_menu = create(:menu, user: create(:user))

      patch adjust_meal_count_menu_path(other_menu),
            params: { meal_type: "dinner", delta: 1 }

      expect(response).to redirect_to(root_path)
    end
  end
end
