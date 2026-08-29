# frozen_string_literal: true

require "rails_helper"

# Pages « Mon compte » et « Nouveau mot de passe ». Elles existaient déjà —
# fournies par le gem Devise — mais dans son habillage par défaut, et la première
# n'était liée nulle part : on ne pouvait y arriver qu'en tapant l'URL.
RSpec.describe "Compte utilisateur", type: :request do
  let(:user) { create(:user, password: "motdepasse") }

  describe "GET /users/edit" do
    before { sign_in user }

    it "s'affiche dans l'habillage du site" do
      get edit_user_registration_path

      expect(response.body).to include("auth-card", "Mon compte")
    end

    it "est accessible depuis le menu utilisateur" do
      get root_path

      expect(response.body).to include(edit_user_registration_path)
    end
  end

  describe "PATCH /users" do
    before { sign_in user }

    # Sans configure_account_update_params, Devise écarte les champs qui ne sont
    # pas les siens : le formulaire semblait accepter le changement, et le
    # prénom restait l'ancien.
    it "enregistre les champs d'identité propres au projet" do
      patch user_registration_path, params: {
        user: { username: "nouveau-pseudo", first_name: "Camille", last_name: "Durand",
                gender: "female", email: user.email, current_password: "motdepasse" }
      }

      expect(user.reload).to have_attributes(username: "nouveau-pseudo", first_name: "Camille")
    end

    it "refuse la modification sans le mot de passe actuel" do
      patch user_registration_path, params: {
        user: { first_name: "Camille", email: user.email, current_password: "" }
      }

      expect(user.reload.first_name).not_to eq("Camille")
    end
  end

  describe "GET /users/password/edit" do
    it "s'affiche dans l'habillage du site" do
      token = user.send(:set_reset_password_token)

      get edit_user_password_path(reset_password_token: token)

      expect(response.body).to include("auth-card", "Nouveau mot de passe")
    end
  end

  # L'œil d'affichage : sur tous les champs de mot de passe du site, et sur eux
  # seuls — un courriel ou un pseudo n'a rien à masquer.
  describe "œil d'affichage" do
    {
      "connexion"          => -> { get new_user_session_path },
      "inscription"        => -> { get new_user_registration_path }
    }.each do |page, visit|
      it "équipe les champs de mot de passe de la page #{page}" do
        instance_exec(&visit)

        expect(response.body.scan(/data-controller="password-visibility"/).size)
          .to eq(response.body.scan(/type="password"/).size)
      end
    end

    it "équipe les trois champs de la page Mon compte" do
      sign_in user

      get edit_user_registration_path

      expect(response.body.scan(/data-controller="password-visibility"/).size).to eq(3)
    end
  end

  describe "PUT /users/password" do
    it "change le mot de passe avec un jeton valide" do
      token = user.send(:set_reset_password_token)

      put user_password_path, params: {
        user: { reset_password_token: token, password: "nouveaumdp", password_confirmation: "nouveaumdp" }
      }

      expect(user.reload.valid_password?("nouveaumdp")).to be(true)
    end
  end
end
