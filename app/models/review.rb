# Représente un avis (note + commentaire) d'un utilisateur sur une recette (UC4)
# Un utilisateur ne peut laisser qu'un seul avis par recette (éditable)
class Review < ApplicationRecord
  # === Associations ===
  belongs_to :user
  belongs_to :recipe

  # === Validations ===
  validates :rating, presence: true, 
                     inclusion: { 
                       in: 1..5, 
                       message: "doit être entre 1 et 5 étoiles" 
                     }
  
  validates :content, length: { maximum: 1000 }, allow_blank: true
  
  # Un utilisateur ne peut laisser qu'un seul avis par recette
  validates :recipe_id, uniqueness: { 
    scope: :user_id,
    message: "a déjà été notée par cet utilisateur"
  }

  # === Scopes ===
  scope :recent, -> { order(created_at: :desc) }
  scope :best_rated, -> { order(rating: :desc) }
  scope :with_content, -> { where.not(content: [nil, '']) }

  # === Délégations ===
  delegate :email, to: :user, prefix: true, allow_nil: true

  # === Méthodes de classe ===

  # Crée ou met à jour un avis (UC4 : un user peut modifier sa note)
  def self.create_or_update_for(user:, recipe:, rating:, content: nil)
    review = find_or_initialize_by(user: user, recipe: recipe)
    review.assign_attributes(rating: rating, content: content)
    review.save
    review
  end

  # === Méthodes d'instance ===

  # Retourne true si l'avis contient un commentaire
  def has_content?
    content.present?
  end

  # Nombre d'étoiles affichées (★★★★★)
  def stars_display
    '★' * rating + '☆' * (5 - rating)
  end
end
