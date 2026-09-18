# frozen_string_literal: true

require "rails_helper"

# Le foyer, de bout en bout : la page « Mon foyer », le lien d'invitation, le
# départ d'un membre — et la raison d'être de tout cela, un menu et une liste de
# courses que deux comptes consultent et cochent ensemble.
RSpec.describe "Foyer", type: :request do
  # Créée d'emblée : le rang d'un membre dans son foyer — l'ordre de la liste et
  # des couleurs d'avatar — suit l'ancienneté des comptes.
  let!(:caroline) { create(:user, first_name: "Caroline", username: "Caro") }
  let(:household) { caroline.household }

  # Un second membre, entré par le lien d'invitation
  def join(user)
    household.admit!(user)
    user
  end

  describe "GET /foyer" do
    it "exige d'être connecté" do
      get household_path

      expect(response).to redirect_to(new_user_session_path)
    end

    it "est accessible depuis le menu utilisateur" do
      sign_in caroline

      get root_path

      expect(response.body).to include(household_path)
    end

    it "affiche les membres et le lien d'invitation à partager" do
      join(create(:user, first_name: "Marc", username: "marc"))
      sign_in caroline

      get household_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Caroline &amp; Marc", "Vous partagez les menus et la liste de courses.",
                                       "2 personnes", "@Caro", "@marc", "Quitter le foyer", "Retirer du foyer")
      expect(response.body).to include(household_invitation_url(household.invite_token))
    end

    # Chaque membre a sa couleur d'avatar, dans l'ordre du foyer — l'en-tête de
    # page reprend celle du compte connecté.
    it "donne à chaque membre sa couleur d'avatar" do
      join(create(:user, first_name: "Marc", username: "marc"))
      sign_in caroline

      get household_path

      expect(response.body).to include('member-avatar" data-member-color="0"', 'member-avatar" data-member-color="1"')
      expect(response.body).to include('user-avatar member-avatar" data-member-color="0"')
    end

    it "ne propose ni de quitter ni de retirer quand on est seul dans son foyer" do
      sign_in caroline

      get household_path

      expect(response.body).to include("1 personne", "Invite quelqu&#39;un")
      expect(response.body).not_to include("Quitter le foyer", "Retirer du foyer")
    end

    it "montre un aperçu des courses habituelles, aux couleurs de leur rayon" do
      household.usual_grocery_items.create!(name: "Dentifrice", category: "hygiene_beaute")
      household.usual_grocery_items.create!(name: "Riz", quantity: 2, unit: "kg", category: "epicerie_salee")
      sign_in caroline

      get household_path

      expect(response.body).to include("Mes courses habituelles", "2 articles, ajoutés d&#39;un bouton",
                                       'data-category="hygiene_beaute"', "Dentifrice", "2 kg", "Gérer la liste")
    end
  end

  describe "GET /menus" do
    it "dit avec qui les menus sont partagés, et mène au foyer" do
      join(create(:user, username: "marc"))
      sign_in caroline

      get menus_path

      expect(response.body).to include("Partagé avec @marc", household_path)
    end

    it "ne dit rien à qui est seul dans son foyer" do
      sign_in caroline

      get menus_path

      expect(response.body).not_to include("Partagé avec")
    end
  end

  describe "PATCH /foyer/renew_invitation" do
    it "remplace le lien : l'ancien ne mène plus au foyer" do
      old_token = household.invite_token
      sign_in caroline

      patch renew_invitation_household_path

      expect(household.reload.invite_token).not_to eq(old_token)

      sign_in create(:user)
      get household_invitation_path(old_token)
      expect(response).to redirect_to(root_path)
      expect(flash[:alert]).to include("ne fonctionne plus")
    end
  end

  describe "le lien d'invitation" do
    let(:marc) { create(:user, first_name: "Marc", username: "marc") }

    it "ramène à l'invitation après la connexion" do
      get household_invitation_path(household.invite_token)
      expect(response).to redirect_to(new_user_session_path)

      post user_session_path, params: { user: { email: marc.email, password: "password123" } }

      expect(response).to redirect_to(household_invitation_path(household.invite_token))
    end

    it "ramène à l'invitation après la création du compte" do
      get household_invitation_path(household.invite_token)

      post user_registration_path, params: { user: {
        email: "lea@exemple.fr", password: "motdepasse123", username: "lea",
        first_name: "Léa", last_name: "Martin", gender: "female"
      } }

      expect(response).to redirect_to(household_invitation_path(household.invite_token))
    end

    it "dit ce qui va changer avant de confirmer" do
      create_list(:menu, 2, user: marc, status: :archived)
      sign_in marc

      get household_invitation_path(household.invite_token)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Caroline (@Caro)", "Tes 2 menus rejoindront l&#39;historique du foyer.")
    end

    it "fait entrer dans le foyer à la confirmation" do
      sign_in marc

      post household_invitation_path(household.invite_token)

      expect(response).to redirect_to(household_path)
      expect(marc.reload.household).to eq(household)
    end

    it "renvoie un membre du foyer vers « Mon foyer » sans rien changer" do
      sign_in caroline

      get household_invitation_path(household.invite_token)

      expect(response).to redirect_to(household_path)
    end

    it "refuse un lien inconnu" do
      sign_in marc

      post household_invitation_path("lien-invente")

      expect(response).to redirect_to(root_path)
      expect(marc.reload.household).not_to eq(household)
    end
  end

  describe "DELETE /foyer/membres/:id" do
    let!(:marc) { join(create(:user, username: "marc")) }
    let!(:menu) { create(:menu, user: caroline, status: :active) }

    it "retire un autre membre, qui perd l'accès aux menus du foyer" do
      sign_in caroline

      delete household_member_path(marc)

      expect(flash[:notice]).to eq("@marc ne fait plus partie du foyer.")
      expect(marc.reload.household).not_to eq(household)

      sign_in marc
      get menu_path(menu)
      expect(flash[:alert]).to include("pas autorisé")
    end

    it "permet de quitter soi-même le foyer, qui garde ses menus" do
      sign_in marc

      delete household_member_path(marc)

      expect(flash[:notice]).to eq("Tu as quitté le foyer.")
      expect(caroline.reload.menus).to eq([ menu ])
    end

    it "refuse le départ du dernier membre" do
      household.release!(marc)
      sign_in caroline

      delete household_member_path(caroline)

      expect(flash[:alert]).to include("seule personne")
      expect(caroline.reload.household).to eq(household)
    end

    it "ne touche pas au membre d'un autre foyer" do
      stranger = create(:user)
      sign_in caroline

      delete household_member_path(stranger)

      expect(response).to have_http_status(:not_found)
      expect(stranger.reload.household).not_to eq(household)
    end
  end

  # Le scénario qui justifie le foyer : l'une compose et valide, l'autre fait
  # les courses sur la même liste.
  describe "menu et liste de courses partagés" do
    let(:marc) { join(create(:user)) }
    let(:menu) { create(:menu, user: caroline, status: :active) }
    let!(:item) { create(:grocery_item, menu: menu, name: "Carottes") }

    it "donne à chaque membre le menu actif et sa liste de courses" do
      sign_in marc

      get grocery_menu_path(menu)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Carottes")
    end

    it "laisse chaque membre cocher un article de la liste" do
      sign_in marc

      patch menu_grocery_item_path(menu, item), params: { grocery_item: { checked: true } },
                                                as: :turbo_stream

      expect(item.reload.checked).to be(true)
    end

    it "reste fermé aux comptes hors du foyer" do
      sign_in create(:user)

      patch menu_grocery_item_path(menu, item), params: { grocery_item: { checked: true } }

      expect(item.reload.checked).to be(false)
    end
  end
end
