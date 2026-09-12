# frozen_string_literal: true

require "rails_helper"

# Trace de l'origine d'une recette importée, sur la fiche publiée.
#
# L'import conserve déjà sa source (source_url, ou source_photo recopiée sur le
# brouillon) et rien ne la purge à la publication. Ce qui se vérifie ici, c'est
# la seule règle qui s'y ajoute : ce que la fiche en montre, et à qui.
RSpec.describe "Source d'import sur la fiche recette", type: :request do
  let(:admin) { create(:user, admin: true) }

  def link_recipe
    create(:recipe, :with_ingredient, source_type: "url", source_url: "https://exemple.fr/tarte")
  end

  def photo_recipe
    create(:recipe, :with_ingredient, :with_source_photo, source_type: "photo")
  end

  describe "import par lien" do
    # Citer sa source est normal : le lien reste visible même déconnecté.
    it "propose la page d'origine à un visiteur non connecté" do
      get recipe_path(link_recipe)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("https://exemple.fr/tarte")
      expect(response.body).to include('rel="noopener noreferrer"')
    end

    it "ouvre la page d'origine dans un nouvel onglet, jamais par-dessus la fiche" do
      get recipe_path(link_recipe)

      expect(response.body).to include('target="_blank"')
    end
  end

  describe "import par photo" do
    # Rediffuser la page photographiée d'un livre ou d'un magazine n'a pas à se
    # faire en public : la pop-up reste une pièce de référence interne.
    it "ne montre rien à un visiteur non connecté" do
      get recipe_path(photo_recipe)

      expect(response).to have_http_status(:ok)
      expect(response.body).not_to include("modal-photo__img")
    end

    it "ne montre rien à un utilisateur connecté sans droits d'admin" do
      sign_in create(:user)

      get recipe_path(photo_recipe)

      expect(response.body).not_to include("modal-photo__img")
    end

    context "connectée en admin" do
      before { sign_in admin }

      it "câble le bouton d'ouverture de la pop-up" do
        get recipe_path(photo_recipe)

        expect(response.body).to include("modal#open")
        expect(response.body).to include("modal-photo__img")
      end

      # La photo se sert par URL de transformation Cloudinary, comme partout
      # ailleurs dans le projet — jamais par variante ActiveStorage.
      it "sert la photo d'origine depuis Cloudinary" do
        get recipe_path(photo_recipe)

        expect(response.body).to include("res.cloudinary.com/easymeal-test/")
        expect(response.body).not_to include("active_storage")
      end

      # Le voile est masqué au chargement : sans lazy, chaque fiche ouverte
      # téléchargerait une photo que personne ne regarde — de la bande passante
      # Cloudinary payée pour rien.
      it "ne fait descendre la photo qu'à l'ouverture de la pop-up" do
        get recipe_path(photo_recipe)

        expect(response.body).to include('loading="lazy"')
      end
    end
  end

  describe "recette saisie à la main" do
    before { sign_in admin }

    it "n'affiche aucun bouton de source" do
      get recipe_path(create(:recipe, :with_ingredient))

      expect(response.body).not_to include("modal-photo__img")
    end

    # Un vieil import photo dont le fichier a disparu ne doit pas rendre une
    # image brisée : le bouton s'efface avec la pièce jointe.
    it "n'affiche aucun bouton quand la photo d'origine a disparu" do
      get recipe_path(create(:recipe, :with_ingredient, source_type: "photo"))

      expect(response.body).not_to include("modal-photo__img")
    end
  end
end
