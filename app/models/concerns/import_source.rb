# frozen_string_literal: true

# D'où vient une recette importée, et ce qu'il en reste une fois publiée.
#
# Un import IA laisse une trace sur la recette qu'il produit : l'adresse de la
# page (`source_url`) ou la page photographiée elle-même (`source_photo`). Les
# deux s'excluent — `source_type` vaut « url » ou « photo », jamais les deux.
#
# Cette trace survit à la validation du brouillon : rien ne la purge, et la
# fiche publiée la rouvre longtemps après, quand il faut confronter une quantité
# à l'original. Une recette saisie à la main n'a pas de source et répond non aux
# deux questions.
#
# Exige PhotoLimits, inclus avant lui : c'est de là que vient validates_photos.
module ImportSource
  extend ActiveSupport::Concern

  included do
    # Page photographiée à l'import IA, conservée comme pièce de référence :
    # pendant la validation elle permet de relire une quantité douteuse, après
    # publication elle reste l'original de la recette. Ce n'est pas une photo du
    # plat — elle ne remplace jamais `photo`, seule image du catalogue. Aucune
    # migration : ActiveStorage range les deux pièces jointes dans
    # active_storage_attachments, distinguées par leur nom.
    has_one_attached :source_photo

    validates_photos :source_photo
  end

  # Import par lien dont la page d'origine reste consultable : la liste des
  # brouillons en fait un badge cliquable, le formulaire de validation un lien
  # de référence, et la fiche publiée un bouton de source. Les vieux imports
  # enregistrés sans source_url retombent sur un affichage sans lien.
  def imported_from_link?
    source_type == "url" && source_url.present?
  end

  # Import par photo dont la page photographiée est toujours là. Un vieil import
  # dont le fichier aurait disparu retombe sur une fiche sans bouton plutôt que
  # sur une image brisée.
  def imported_from_photo?
    source_type == "photo" && source_photo.attached?
  end
end
