# frozen_string_literal: true

require "rails_helper"

# Lecture de la définition d'une image dans son en-tête. C'est ce qui permet de
# refuser les 48 mégapixels d'un téléphone récent sans décoder l'image, et sans
# bibliothèque de traitement d'image sur le serveur.
RSpec.describe Images::Dimensions do
  # En-tête PNG minimal : signature, puis le chunk IHDR qui ouvre
  # obligatoirement le format et porte la définition sur deux entiers 32 bits.
  def png_header(width, height)
    StringIO.new(
      "#{Images::Dimensions::PNG_SIGNATURE}#{[ 13 ].pack('N')}IHDR#{[ width, height ].pack('N2')}"
    )
  end

  # En-tête JPEG minimal : SOI, un segment de métadonnées à sauter, puis le SOF
  # qui annonce la hauteur avant la largeur.
  def jpeg_header(width, height, metadata_bytes: 12)
    metadata = "#{[ 0xFF, 0xE0 ].pack('C2')}#{[ metadata_bytes + 2 ].pack('n')}#{'x' * metadata_bytes}"
    sof = "#{[ 0xFF, 0xC0 ].pack('C2')}#{[ 11 ].pack('n')}#{[ 8 ].pack('C')}#{[ height, width ].pack('n2')}"

    StringIO.new("#{Images::Dimensions::JPEG_SIGNATURE}#{metadata}#{sof}#{'x' * 6}")
  end

  describe "PNG" do
    it "lit la définition dans le chunk IHDR" do
      expect(described_class.read(png_header(1920, 1080))).to eq([ 1920, 1080 ])
    end
  end

  describe "JPEG" do
    it "lit la définition dans le segment SOF" do
      expect(described_class.read(jpeg_header(4032, 3024))).to eq([ 4032, 3024 ])
    end

    # Le cas réel : une photo de téléphone place EXIF, vignette et profil
    # couleur avant le SOF. Chaque segment annonce sa longueur, ce qui permet
    # de les enjamber sans les interpréter.
    it "enjambe les métadonnées volumineuses qui précèdent le SOF" do
      expect(described_class.read(jpeg_header(8000, 6000, metadata_bytes: 60_000))).to eq([ 8000, 6000 ])
    end

    it "reconnaît aussi un SOF progressif" do
      progressive = jpeg_header(1024, 768).string.sub([ 0xFF, 0xC0 ].pack("C2"), [ 0xFF, 0xC2 ].pack("C2"))

      expect(described_class.read(StringIO.new(progressive))).to eq([ 1024, 768 ])
    end
  end

  describe "ce qui n'est pas lisible" do
    # Rendre nil plutôt que lever : l'appelant s'en remet alors au plafond de
    # poids, et une image exotique n'empêche jamais un enregistrement.
    it "rend nil pour un format sans en-tête reconnu" do
      expect(described_class.read(StringIO.new("GIF89a peu importe la suite"))).to be_nil
    end

    it "rend nil pour un JPEG tronqué avant son SOF" do
      truncated = Images::Dimensions::JPEG_SIGNATURE + [ 0xFF, 0xE0 ].pack("C2")

      expect(described_class.read(StringIO.new(truncated))).to be_nil
    end

    it "rend nil quand rien n'est lisible" do
      expect(described_class.read(nil)).to be_nil
    end
  end

  # Le flux est ensuite relu par ActiveStorage pour calculer l'empreinte et
  # téléverser le fichier : le laisser à mi-course tronquerait l'upload.
  it "rembobine le flux qu'il a lu" do
    io = png_header(800, 600)
    described_class.read(io)

    expect(io.pos).to eq(0)
  end
end
