require "rails_helper"

RSpec.describe ApplicationHelper, type: :helper do
  let(:user) { create(:user) }

  describe "#greeting_context" do
    it "annonce une liste prête uniquement pour un menu actif avec articles" do
      active_menu = create(:menu, user: user, status: :active)
      create(:grocery_item, menu: active_menu)

      expect(helper.greeting_context(active_menu: active_menu, draft: nil)).to eq(:grocery_list_ready)
    end

    it "distingue un menu actif sans liste de courses" do
      active_menu = create(:menu, user: user, status: :active)

      expect(helper.greeting_context(active_menu: active_menu, draft: nil)).to eq(:active_menu_ready)
    end

    it "n'annonce pas une liste prête pour un menu en revalidation" do
      draft = create(:menu, user: user, status: :draft)
      create(:grocery_item, menu: draft)

      expect(helper.greeting_context(active_menu: nil, draft: draft)).to eq(:pending_revalidation)
    end

    it "invite à valider un brouillon sans liste" do
      draft = create(:menu, user: user, status: :draft)

      expect(helper.greeting_context(active_menu: nil, draft: draft)).to eq(:draft_ready)
    end
  end
end