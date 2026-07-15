# frozen_string_literal: true

require "rails_helper"

RSpec.describe "POST /menus/:id/revert_to_draft", type: :request do
  let(:user) { create(:user) }
  let(:menu) { create(:menu, user: user, status: :active) }

  context "quand l'utilisateur est propriétaire" do
    before { sign_in user }

    it "repasse le menu en brouillon" do
      post revert_to_draft_menu_path(menu)

      expect(response).to have_http_status(:see_other)
      expect(menu.reload).to be_status_draft
    end
  end

  context "quand l'utilisateur n'est pas propriétaire" do
    before { sign_in create(:user) }

    it "refuse et laisse le menu actif" do
      post revert_to_draft_menu_path(menu)

      expect(menu.reload).to be_status_active
      expect(response).to redirect_to(root_path)
    end
  end
end
