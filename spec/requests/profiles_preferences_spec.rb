# frozen_string_literal: true

require "rails_helper"

# UC7, chapitre 2 — la semaine type se décrit aussi depuis les réglages du foyer,
# avec exactement les mêmes steppers que le formulaire de génération.
RSpec.describe "Réglages du foyer", type: :request do
  let(:user) { create(:user) }

  before { sign_in user }

  describe "GET /profile/preferences" do
    it "pré-remplit les steppers avec la répartition mémorisée" do
      user.update!(default_meal_counts: { "snack" => 3 })

      get preferences_profile_path

      expect(response).to have_http_status(:success)
      expect(response.body).to include('name="user[default_meal_counts][snack]"')
      expect(response.body).to include("Répartition des repas")
    end
  end

  describe "PATCH /profile/preferences" do
    it "enregistre la répartition et ignore les moments inconnus" do
      patch preferences_profile_path, params: {
        user: {
          default_diet: "vegetarien",
          default_people: 5,
          default_meal_counts: { breakfast: "7", brunch: "4", dinner: "7", same_breakfast: "1" }
        }
      }

      counts = user.reload.preferred_meal_counts
      expect(counts.to_h).to eq({ "breakfast" => 7, "dinner" => 7, "same_breakfast" => true })
      expect(user.default_people).to eq(5)
      expect(user).to be_preferences_configured
    end

    it "accepte une semaine remise à zéro" do
      user.update!(default_meal_counts: { "dinner" => 7 })

      patch preferences_profile_path, params: {
        user: { default_diet: "omnivore", default_people: 2,
                default_meal_counts: { dinner: "0" } }
      }

      expect(user.reload.preferred_meal_counts.any?).to be(false)
    end
  end
end
