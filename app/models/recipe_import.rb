# frozen_string_literal: true

# Une tentative d'import IA, de la source déposée au brouillon obtenu.
#
# Elle existe dès la soumission du formulaire, avant que l'IA n'ait répondu :
# c'est ce qui permet à la page d'attente de dire où en est le travail, et à un
# import de survivre au redémarrage du serveur. Le brouillon (`recipe`) n'arrive
# qu'à la réussite ; en cas d'échec, `error_message` porte le motif montré à
# l'utilisatrice.
class RecipeImport < ApplicationRecord
  belongs_to :user

  # Le brouillon produit par l'extraction. Optionnel par nature : il n'existe
  # pas tant que l'IA n'a pas répondu, et jamais si elle échoue.
  belongs_to :recipe, optional: true

  # La page photographiée voyage avec l'import : le job la relit pour l'envoyer à
  # l'IA, et le brouillon en garde ensuite une copie comme pièce de référence
  # pour la validation.
  has_one_attached :source_photo

  # Format, poids et définition acceptés par Cloudinary : une photo hors limites
  # doit être refusée ici, tant que l'utilisatrice est devant le formulaire — pas
  # au fond du job, où l'upload échouerait sans rien lui dire d'utile.
  include PhotoLimits
  validates_photos :source_photo

  # Les deux portes d'entrée de l'import. Le formulaire n'en propose pas d'autre,
  # mais un import n'a pas à faire confiance à ce qu'on lui soumet.
  SOURCE_TYPES = %w[url photo].freeze

  enum :status, { pending: 0, processing: 1, succeeded: 2, failed: 3 }, default: :pending

  validates :source_type, presence: true, inclusion: { in: SOURCE_TYPES }
  validates :source_url, presence: true, if: :from_url?

  def from_url?
    source_type == "url"
  end

  # Plus rien à attendre : la page d'attente peut cesser de revenir voir.
  def finished?
    succeeded? || failed?
  end

  # Fin de course en échec, motif compris. Le statut et la raison s'écrivent
  # ensemble : un import échoué sans motif ne laisserait rien à afficher.
  def fail_with!(message)
    update!(status: :failed, error_message: message)
  end

  # Fin de course réussie : le brouillon est là, l'utilisatrice peut le valider.
  def succeed_with!(recipe)
    update!(status: :succeeded, recipe: recipe, error_message: nil)
  end
end
