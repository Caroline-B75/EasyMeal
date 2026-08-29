# frozen_string_literal: true

require "rails_helper"

# Zone photo du formulaire de recette : le fichier peut arriver par clic, par
# glisser-déposer ou par collage d'une capture d'écran. Les gestes vivent dans
# le contrôleur Stimulus — côté requêtes, seul leur branchement est vérifiable,
# et c'est lui qui saute si la vue change.
RSpec.describe "Zone photo du formulaire de recette", type: :request do
  let(:admin) { create(:user, admin: true) }

  before { sign_in admin }

  it "câble le dépôt de fichier et le collage sur le formulaire de création" do
    get new_recipe_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("drop-&gt;image-preview#dropFile")
    expect(response.body).to include("paste@document-&gt;image-preview#paste")
  end

  it "rend l'aperçu du fichier choisi, masqué tant qu'aucun fichier n'est choisi" do
    get new_recipe_path

    expect(response.body).to include("photo-preview--chosen")
  end

  it "câble les mêmes gestes à l'édition d'une recette existante" do
    get edit_recipe_path(create(:recipe, :with_ingredient))

    expect(response.body).to include("drop-&gt;image-preview#dropFile")
    expect(response.body).to include("paste@document-&gt;image-preview#paste")
  end

  describe "envoi d'une photo à la création" do
    let(:ingredient) { create(:ingredient) }

    # Un en-tête JPEG suffit à annoncer la définition voulue ; le fichier, lui,
    # reste minuscule. C'est ce qui permet de rejouer le piège du téléphone
    # récent — 48 mégapixels dans un fichier que le plafond de poids laisserait
    # passer — sans trimballer une vraie photo dans la suite.
    def jpeg_upload(width:, height:)
      file = Tempfile.new([ "photo", ".jpg" ], binmode: true)
      file.write("\xFF\xD8\xFF\xC0".b + [ 11 ].pack("n") + [ 8 ].pack("C") +
                 [ height, width ].pack("n2") + ("x" * 6))
      file.rewind

      Rack::Test::UploadedFile.new(file.path, "image/jpeg")
    end

    def post_recipe(photo)
      post recipes_path, params: {
        recipe: {
          name: "Tarte aux pommes", diet: "omnivore", default_servings: 4,
          meal_types: [ "dinner" ], photo: photo,
          preparations_attributes: { "0" => { ingredient_id: ingredient.id, quantity_base: 100 } }
        }
      }
    end

    # Filet serveur : le navigateur réduit la photo avant l'envoi, mais quand
    # cette réduction échoue, c'est le formulaire qui doit dire pourquoi le
    # fichier ne passe pas — et non Cloudinary, hors de portée de l'utilisatrice.
    it "renvoie le formulaire et affiche le motif du refus" do
      post_recipe(jpeg_upload(width: 8000, height: 6000))

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.body).to include("dépasse 25 mégapixels")
      expect(Recipe.count).to eq(0)
    end

    # ActiveStorage analyse par défaut chaque pièce jointe dans un job qui
    # RETÉLÉCHARGE le fichier depuis le service de stockage — de la bande
    # passante Cloudinary facturée à chaque envoi, pour une largeur et une
    # hauteur que le projet ne lit nulle part. config/application.rb vide la
    # liste des analyseurs ; cet exemple est ce qui le rappellera si un jour
    # une mise à jour de Rails ou un ajout d'analyseur la remplit.
    it "n'enfile aucun job d'analyse : la photo n'est jamais retéléchargée" do
      expect { post_recipe(jpeg_upload(width: 1200, height: 1600)) }
        .not_to have_enqueued_job(ActiveStorage::AnalyzeJob)

      expect(Recipe.last.photo).to be_attached
    end
  end
end
