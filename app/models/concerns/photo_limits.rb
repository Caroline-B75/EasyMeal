# frozen_string_literal: true

# Plafonds Cloudinary appliqués côté serveur aux photos déposées.
#
# Cloudinary refuse une image de plus de 10 Mo ou de plus de 25 mégapixels — et
# un téléphone récent photographie couramment en 48 MP, ce qui dépasse la
# définition sans forcément dépasser le poids. Le navigateur réduit déjà toute
# photo avant l'envoi (cf. app/javascript/image_downscale.js), mais cette
# réduction reste une optimisation qui rend le fichier d'origine au moindre
# accroc — format illisible, mémoire. Sans ce filet, la photo partirait quand
# même et ne serait refusée qu'à l'upload : côté import, dans un job de fond
# dont l'échec ne dit rien à l'utilisatrice.
#
# Usage : `include PhotoLimits`, puis `validates_photos :photo, :source_photo`.
module PhotoLimits
  extend ActiveSupport::Concern

  # Repris tels quels des limites du compte Cloudinary : les dépasser d'un octet
  # ou d'un pixel suffit à faire refuser l'upload.
  MAX_BYTES = 10.megabytes
  MAX_PIXELS = 25_000_000

  # Ce que Cloudinary sait lire et que le catalogue sait afficher. Le HEIC des
  # iPhone n'y figure pas : le sélecteur de fichiers le convertit en JPEG à la
  # volée, et un HEIC qui arriverait tout de même ne serait lisible ni par la
  # réduction du navigateur ni par Cloudinary.
  CONTENT_TYPES = %w[image/jpeg image/png image/webp].freeze

  class_methods do
    # Applique les plafonds à chacune des pièces jointes nommées.
    def validates_photos(*names)
      names.each { |name| validate { validate_photo_limits(name) } }
    end
  end

  private

  # Seule une pièce jointe qui vient d'être déposée est contrôlée : une photo
  # déjà stockée a passé ces règles à son arrivée, et la relire coûterait un
  # aller-retour vers Cloudinary à chaque sauvegarde.
  def validate_photo_limits(name)
    change = attachment_changes[name.to_s]
    return unless change.is_a?(ActiveStorage::Attached::Changes::CreateOne)

    # Un format non reconnu rend les deux autres contrôles sans objet : le poids
    # d'un PDF ne dit rien, et sa définition encore moins.
    unless CONTENT_TYPES.include?(change.blob.content_type)
      errors.add(name, "doit être une image JPEG, PNG ou WebP")
      return
    end

    if change.blob.byte_size > MAX_BYTES
      errors.add(name, "est trop lourde (#{MAX_BYTES / 1.megabyte} Mo maximum)")
    end

    if too_many_pixels?(change.attachable)
      errors.add(name, "dépasse #{MAX_PIXELS / 1_000_000} mégapixels : réduis sa définition")
    end
  end

  # Une définition illisible ne fait rien échouer — format sans en-tête reconnu,
  # ou pièce jointe recopiée depuis un blob déjà stocké, qu'il faudrait
  # retélécharger pour inspecter. Le plafond de poids reste alors seul à jouer.
  def too_many_pixels?(attachable)
    dimensions = Images::Dimensions.read(readable_io(attachable))
    return false unless dimensions

    dimensions.reduce(:*) > MAX_PIXELS
  end

  # Le fichier tel qu'il arrive du formulaire. ActiveStorage accepte plusieurs
  # formes d'attachable : on ramène au flux lisible celles qui en portent un.
  def readable_io(attachable)
    return attachable.tempfile if attachable.respond_to?(:tempfile)
    return attachable[:io] if attachable.is_a?(Hash)

    attachable
  end
end
