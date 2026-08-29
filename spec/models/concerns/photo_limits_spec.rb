# frozen_string_literal: true

require "rails_helper"

# Filet serveur des plafonds Cloudinary. Le navigateur réduit déjà chaque photo
# avant l'envoi, mais cette réduction rend le fichier d'origine au moindre
# accroc : ces règles sont ce qui empêche alors la photo de partir pour être
# refusée à l'upload, hors de portée de l'utilisatrice.
RSpec.describe PhotoLimits do
  # En-tête JPEG suffisant pour que la définition soit lisible : SOI, SOF, et de
  # quoi remplir le fichier au poids voulu.
  def jpeg(width:, height:, bytes: 1_000)
    header = "\xFF\xD8\xFF\xC0".b +
             [ 11 ].pack("n") + [ 8 ].pack("C") + [ height, width ].pack("n2") +
             ("x" * 6)

    StringIO.new(header + ("x" * [ bytes - header.bytesize, 0 ].max))
  end

  def recipe_with_photo(io, filename: "plat.jpg", content_type: "image/jpeg")
    build(:recipe, :with_ingredient).tap do |recipe|
      recipe.photo.attach(io: io, filename: filename, content_type: content_type)
    end
  end

  describe "format" do
    it "accepte une image JPEG" do
      expect(recipe_with_photo(jpeg(width: 1600, height: 1200))).to be_valid
    end

    it "refuse un format que Cloudinary ne sert pas" do
      recipe = recipe_with_photo(StringIO.new("%PDF-1.7"), filename: "recette.pdf", content_type: "application/pdf")

      expect(recipe).not_to be_valid
      expect(recipe.errors[:photo]).to include("doit être une image JPEG, PNG ou WebP")
    end

    # Un format refusé rend les deux autres contrôles sans objet : le poids d'un
    # PDF ne dit rien, et sa définition encore moins.
    it "ne cumule pas d'autre reproche avec un format refusé" do
      recipe = recipe_with_photo(StringIO.new("x" * 11.megabytes),
                                 filename: "gros.pdf", content_type: "application/pdf")

      recipe.validate

      expect(recipe.errors[:photo].size).to eq(1)
    end
  end

  describe "poids" do
    it "accepte une photo sous les 10 Mo" do
      expect(recipe_with_photo(jpeg(width: 1600, height: 1200, bytes: 2.megabytes))).to be_valid
    end

    it "refuse une photo au-delà des 10 Mo que Cloudinary accepte" do
      recipe = recipe_with_photo(jpeg(width: 1600, height: 1200, bytes: 11.megabytes))

      expect(recipe).not_to be_valid
      expect(recipe.errors[:photo]).to include("est trop lourde (10 Mo maximum)")
    end
  end

  describe "définition" do
    # Le piège que le seul plafond de poids laisse passer : un téléphone récent
    # photographie en 48 MP, bien au-delà des 25 MP de Cloudinary, sans que le
    # fichier compressé pèse forcément 10 Mo.
    it "refuse une photo au-delà des 25 mégapixels, même légère" do
      recipe = recipe_with_photo(jpeg(width: 8000, height: 6000, bytes: 3.megabytes))

      expect(recipe).not_to be_valid
      expect(recipe.errors[:photo]).to include("dépasse 25 mégapixels : réduis sa définition")
    end

    it "accepte la définition d'une photo réduite par le navigateur" do
      expect(recipe_with_photo(jpeg(width: 1600, height: 1200))).to be_valid
    end

    # Rien ne doit échouer faute d'avoir su lire l'en-tête : le plafond de poids
    # reste alors seul à jouer.
    it "laisse passer une image dont la définition n'est pas lisible" do
      expect(recipe_with_photo(StringIO.new("contenu opaque"))).to be_valid
    end
  end

  describe "portée des contrôles" do
    it "applique les mêmes règles à la photo de la page importée" do
      recipe = build(:recipe, :with_ingredient)
      recipe.source_photo.attach(io: jpeg(width: 8000, height: 6000), filename: "page.jpg", content_type: "image/jpeg")

      expect(recipe).not_to be_valid
      expect(recipe.errors[:source_photo]).to include("dépasse 25 mégapixels : réduis sa définition")
    end

    it "refuse aussi la photo confiée à un import, avant que le job ne parte" do
      import = build(:recipe_import, source_type: "photo", source_url: nil)
      import.source_photo.attach(io: jpeg(width: 1600, height: 1200, bytes: 11.megabytes),
                                 filename: "page.jpg", content_type: "image/jpeg")

      expect(import).not_to be_valid
      expect(import.errors[:source_photo]).to include("est trop lourde (10 Mo maximum)")
    end

    # Relire une photo déjà stockée coûterait un aller-retour vers Cloudinary à
    # chaque sauvegarde, pour des règles qu'elle a passées à son arrivée.
    it "ne recontrôle pas une photo déjà attachée" do
      recipe = create(:recipe, :with_ingredient, :with_photo)

      expect(Images::Dimensions).not_to receive(:read)
      expect(recipe.update(name: "Tarte aux pommes")).to be(true)
    end
  end
end
