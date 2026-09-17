# frozen_string_literal: true

require "rails_helper"

RSpec.describe "POST /menus/:id/revert_to_draft", type: :request do
  let(:user) { create(:user) }
  let(:menu) { create(:menu, user: user, status: :active) }

  context "quand l'utilisateur est membre du foyer" do
    before { sign_in user }

    it "repasse le menu en brouillon" do
      post revert_to_draft_menu_path(menu)

      expect(response).to have_http_status(:see_other)
      expect(menu.reload).to be_status_draft
    end

    # Quelqu'un du foyer peut être en train de faire les courses : sa liste ne
    # disparaît pas sous ses yeux, elle prévient seulement qu'elle peut bouger.
    context "avec une liste de courses déjà faite" do
      before { create(:grocery_item, menu: menu, name: "Carottes") }

      it "laisse la liste consultable, en annonçant la modification en cours" do
        post revert_to_draft_menu_path(menu)

        get grocery_menu_path(menu)

        expect(response).to have_http_status(:ok)
        expect(response.body).to include("Carottes", "Ce menu est en cours de modification",
                                         "les articles déjà cochés le restent")
      end

      it "annonce le membre du foyer qui modifie, quand le foyer est partagé" do
        user.household.admit!(create(:user, username: "marc"))
        post revert_to_draft_menu_path(menu)

        get grocery_menu_path(menu)

        expect(response.body).to include("Un membre du foyer est en train de modifier ce menu")
      end

      it "garde le lien « Courses » dans la navigation" do
        post revert_to_draft_menu_path(menu)

        get menus_path

        expect(response.body).to include(grocery_menu_path(menu))
      end

      it "demande aux écrans ouverts sur la liste de se rafraîchir" do
        expect { menu.revert_to_draft! }
          .to have_enqueued_job(Turbo::Streams::BroadcastStreamJob)
          .with("#{menu.to_gid_param}:grocery", content: include('action="refresh"'))
      end

      it "refuse toujours de régénérer la liste d'un brouillon" do
        post revert_to_draft_menu_path(menu)

        post regenerate_grocery_menu_path(menu)

        expect(flash[:alert]).to include("menu actif")
      end
    end

    it "renvoie vers le menu quand la liste n'existe pas encore" do
      post revert_to_draft_menu_path(menu)

      get grocery_menu_path(menu)

      expect(response).to redirect_to(menu_path(menu))
      expect(flash[:alert]).to include("menu actif")
    end
  end

  context "quand l'utilisateur n'est pas membre du foyer" do
    before { sign_in create(:user) }

    it "refuse et laisse le menu actif" do
      post revert_to_draft_menu_path(menu)

      expect(menu.reload).to be_status_active
      expect(response).to redirect_to(root_path)
    end
  end
end
