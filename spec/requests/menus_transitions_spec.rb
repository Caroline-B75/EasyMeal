# frozen_string_literal: true

require "rails_helper"

# Les trois transitions d'état d'un menu partagent le même filet d'erreur
# (MenusController#transition_menu) : un échec MÉTIER devient un flash d'alerte,
# un bug de programmation remonte normalement.
RSpec.describe "Transitions d'état d'un menu", type: :request do
  let(:user) { create(:user) }

  before { sign_in user }

  # Un échec métier reste un message poli : redirection vers le menu et flash
  # préfixé, sans qu'aucune exception ne s'échappe du contrôleur.
  shared_examples "un échec métier" do |alert_prefix|
    it "redirige vers le menu avec le flash d'alerte attendu" do
      expect { post path }.not_to raise_error

      expect(response).to have_http_status(:see_other)
      expect(response).to redirect_to(menu_path(menu))
      expect(flash[:alert]).to start_with(alert_prefix)
    end
  end

  describe "POST /menus/:id/activate" do
    # Validation en échec : le nom est vidé hors validations, comme le ferait une
    # donnée devenue invalide. update!(status: :active) la refuse → RecordInvalid.
    let(:menu) { create(:menu, user: user, status: :draft).tap { |m| m.update_column(:name, "") } }
    let(:path) { activate_menu_path(menu) }

    include_examples "un échec métier", "Impossible d'activer le menu"

    it "laisse remonter un bug de programmation au lieu d'en faire un flash" do
      allow_any_instance_of(Menu).to receive(:activate!).and_raise(NoMethodError)

      expect { post path }.to raise_error(NoMethodError)
    end
  end

  describe "POST /menus/:id/reactivate" do
    # Garde d'état : seul un menu archivé peut être réactivé.
    let(:menu) { create(:menu, user: user, status: :active) }
    let(:path) { reactivate_menu_path(menu) }

    include_examples "un échec métier", "Impossible de réactiver le menu"
  end

  describe "POST /menus/:id/revert_to_draft" do
    # Garde d'état : seul un menu actif peut repasser en brouillon.
    let(:menu) { create(:menu, user: user, status: :draft) }
    let(:path) { revert_to_draft_menu_path(menu) }

    include_examples "un échec métier", "Impossible de repasser le menu en brouillon"
  end
end
