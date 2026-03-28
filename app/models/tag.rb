# Représente un tag/label pour catégoriser les recettes
# Exemples : "rapide", "sans gluten", "pour enfants", "apéritif", "dessert"
class Tag < ApplicationRecord
  # === Associations ===
  has_many :recipe_tags, dependent: :destroy
  has_many :recipes, through: :recipe_tags

  # === Enums ===
  # Type de tag (optionnel, pour organiser les tags par catégorie)
  enum :tag_type, {
    regime_alimentaire: 0, # Régime alimentaire (sans gluten, sans lactose, etc.)
    occasion: 1,          # Occasion (apéritif, dessert, brunch, etc.)
    methode_cuisson: 2,   # Méthode de cuisson (four, thermomix, BBQ, etc.)
    saison: 3,            # Saison (été, hiver, etc.)
    rapidite: 4,          # Rapidité (rapide, express, etc.)
    autre: 5              # Autre
  }, prefix: true

  # === Validations ===
  validates :name, presence: true,
                   uniqueness: { case_sensitive: false },
                   length: { minimum: 2, maximum: 50 }

  # === Scopes ===
  scope :alphabetical, -> { order(:name) }
  scope :by_type, ->(type) { where(tag_type: type) if type.present? }
  scope :search, ->(query) { where("name ILIKE ?", "%#{query}%") if query.present? }

  # === Callbacks ===
  # Normalise le nom du tag (minuscules, trim)
  before_validation :normalize_name

  # === Méthodes d'instance ===

  # Nombre de recettes utilisant ce tag
  def recipes_count
    recipes.count
  end

  private

  def normalize_name
    self.name = name&.strip&.downcase
  end
end
