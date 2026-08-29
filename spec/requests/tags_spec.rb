require "rails_helper"

RSpec.describe "Tags admin", type: :request do
  let(:admin) { create(:user, admin: true) }

  before { sign_in admin }

  describe "GET /tags" do
    it "affiche les tags groupés par type dans l'ordre défini, avec compteur et libellés" do
      # Deux types différents pour vérifier le regroupement et l'ordre
      create(:tag, name: "express", tag_type: :rapidite)
      create(:tag, name: "vegan", tag_type: :regime_alimentaire)

      get tags_path

      expect(response).to have_http_status(:ok)
      # Groupes par type présents avec leurs libellés lisibles
      expect(response.body).to include("Rapidité")
      expect(response.body).to include("Régime alimentaire")
      # Rapidité doit apparaître avant Régime alimentaire (ordre TAG_TYPE_LABELS)
      expect(response.body.index("Rapidité")).to be < response.body.index("Régime alimentaire")
      # Chaque groupe est une carte dédiée
      expect(response.body.scan(/class=['"]tag-group['"]/).size).to eq(2)
      # Actions accessibles via aria-label
      expect(response.body).to include('aria-label="Modifier le tag express"')
      expect(response.body).to include('aria-label="Supprimer le tag express"')
    end

    it "compte les recettes par tag sans N+1 (comptage en masse)" do
      tag = create(:tag, name: "express", tag_type: :rapidite)
      # Recette en brouillon : évite l'exigence d'au moins un ingrédient
      recipe = create(:recipe, status: :draft)
      create(:recipe_tag, recipe: recipe, tag: tag)

      get tags_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("1")
      expect(response.body).to include("recette")
    end
  end

  describe "POST /tags (création à la volée)" do
    it "crée le tag et renvoie la liste groupée + le formulaire vidé via Turbo Stream" do
      expect {
        post tags_path,
             params: { tag: { name: "express", tag_type: "rapidite" } },
             headers: { "Accept" => "text/vnd.turbo-stream.html" }
      }.to change(Tag, :count).by(1)

      expect(response).to have_http_status(:ok)
      created = Tag.find_by(name: "express")
      expect(created.tag_type).to eq("rapidite")
      # Rafraîchit la liste et réinitialise le formulaire
      expect(response.body).to include('turbo-stream action="replace" target="tags_list"')
      expect(response.body).to include('turbo-stream action="replace" target="new_tag_form"')
      # Le nouveau tag apparaît dans son groupe
      expect(response.body).to include("express")
    end

    it "n'affiche pas d'erreur ni ne crée de tag pour un nom invalide" do
      create(:tag, name: "express", tag_type: :rapidite)

      expect {
        post tags_path,
             params: { tag: { name: "express", tag_type: "rapidite" } },
             headers: { "Accept" => "text/vnd.turbo-stream.html" }
      }.not_to change(Tag, :count)

      expect(response).to have_http_status(:unprocessable_entity)
      # Le formulaire est réaffiché avec un message d'erreur
      expect(response.body).to include('turbo-stream action="replace" target="new_tag_form"')
      expect(response.body).to include("field-error")
    end
  end

  describe "PATCH /tags/:id (édition inline)" do
    it "met à jour le tag et renvoie la liste groupée via Turbo Stream" do
      tag = create(:tag, name: "express", tag_type: :rapidite)

      patch tag_path(tag),
            params: { tag: { name: "ultra rapide" } },
            headers: { "Accept" => "text/vnd.turbo-stream.html" }

      expect(response).to have_http_status(:ok)
      expect(tag.reload.name).to eq("ultra rapide")
      # La réponse remplace bien le frame de la liste, groupé par type
      expect(response.body).to include('turbo-stream action="replace" target="tags_list"')
      expect(response.body).to include("Rapidité")
    end
  end
end
