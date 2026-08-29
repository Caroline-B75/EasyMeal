require "rails_helper"

# Les parcours d'authentification n'étaient couverts par aucune spec : les autres
# passent toutes par le raccourci `sign_in user`, qui court-circuite les
# contrôleurs de Devise. Inscription, connexion et « mot de passe oublié »
# n'étaient donc jamais exercés pour de vrai.
#
# Ce fichier comble ce trou. Il a servi de filet avant la montée en Devise 5, et
# il reste le seul endroit qui vérifie le parcours de réinitialisation — celui
# que la configuration SMTP de production rend possible.
RSpec.describe "Authentification", type: :request do
  describe "inscription" do
    it "affiche le formulaire" do
      get new_user_registration_path

      expect(response).to have_http_status(:success)
    end

    it "crée le compte et ouvre la session" do
      expect {
        post user_registration_path, params: { user: {
          email: "nouvelle@exemple.fr", password: "motdepasse123",
          username: "nouvelle", first_name: "Camille", last_name: "Durand",
          gender: "female"
        } }
      }.to change(User, :count).by(1)

      expect(response).to have_http_status(:redirect)

      # La session est bien ouverte : une page protégée répond au lieu de
      # renvoyer au formulaire de connexion.
      get menus_path
      expect(response).to have_http_status(:success)
    end

    it "refuse un compte incomplet sans rien créer" do
      expect {
        post user_registration_path,
             params: { user: { email: "vide@exemple.fr", password: "motdepasse123" } }
      }.not_to change(User, :count)
    end
  end

  describe "connexion" do
    let!(:user) { create(:user, email: "connue@exemple.fr", password: "motdepasse123") }

    it "affiche le formulaire" do
      get new_user_session_path

      expect(response).to have_http_status(:success)
    end

    it "accepte les bons identifiants" do
      post user_session_path, params: { user: { email: "connue@exemple.fr", password: "motdepasse123" } }

      expect(response).to have_http_status(:redirect)

      get menus_path
      expect(response).to have_http_status(:success)
    end

    # Assertion portée sur le comportement plutôt que sur le code HTTP : Devise a
    # changé plusieurs fois de réponse en cas d'échec selon les versions et la
    # compatibilité Turbo. Ce qui compte, c'est qu'aucune session ne s'ouvre.
    it "refuse un mauvais mot de passe et n'ouvre aucune session" do
      post user_session_path, params: { user: { email: "connue@exemple.fr", password: "faux" } }

      get menus_path
      expect(response).to redirect_to(new_user_session_path)
    end
  end

  describe "mot de passe oublié" do
    let!(:user) { create(:user, email: "oubli@exemple.fr", password: "ancienmotdepasse") }

    it "affiche le formulaire" do
      get new_user_password_path

      expect(response).to have_http_status(:success)
    end

    it "envoie l'email de réinitialisation à la bonne adresse" do
      expect {
        post user_password_path, params: { user: { email: "oubli@exemple.fr" } }
      }.to change { ActionMailer::Base.deliveries.size }.by(1)

      mail = ActionMailer::Base.deliveries.last
      expect(mail.to).to eq([ "oubli@exemple.fr" ])
      # L'expéditeur vient de config.mailer_sender, réglé sur le domaine.
      expect(mail.from).to eq([ "contact@myeasymeal.fr" ])
    end

    it "n'envoie aucun email pour une adresse inconnue" do
      expect {
        post user_password_path, params: { user: { email: "inconnue@exemple.fr" } }
      }.not_to change { ActionMailer::Base.deliveries.size }

      # Devise réaffiche le formulaire avec une erreur (422) plutôt que de
      # rediriger. À noter : il annonce explicitement « email non trouvé », donc
      # le formulaire permet de savoir si une adresse est inscrite chez nous
      # (`config.paranoid` est à false). Choix à trancher séparément — cette
      # spec constate le comportement actuel, elle ne le cautionne pas.
      expect(response).to have_http_status(422)
    end

    it "permet de choisir un nouveau mot de passe avec le jeton reçu" do
      token = user.send_reset_password_instructions

      patch user_password_path, params: { user: {
        reset_password_token: token,
        password: "nouveaumotdepasse",
        password_confirmation: "nouveaumotdepasse"
      } }

      expect(response).to have_http_status(:redirect)
      expect(user.reload.valid_password?("nouveaumotdepasse")).to be true
    end

    it "refuse un jeton invalide" do
      patch user_password_path, params: { user: {
        reset_password_token: "jeton-invente",
        password: "nouveaumotdepasse",
        password_confirmation: "nouveaumotdepasse"
      } }

      expect(user.reload.valid_password?("nouveaumotdepasse")).to be false
    end
  end
end
