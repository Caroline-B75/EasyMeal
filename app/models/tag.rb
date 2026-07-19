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

  # Libellés lisibles des types, dans l'ordre d'affichage souhaité pour l'admin.
  # L'ordre de ce hash pilote l'ordre des groupes affichés.
  TAG_TYPE_LABELS = {
    "rapidite"           => "Rapidité",
    "regime_alimentaire" => "Régime alimentaire",
    "occasion"           => "Occasion",
    "methode_cuisson"    => "Méthode de cuisson",
    "saison"             => "Saison",
    "autre"              => "Autre"
  }.freeze

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

  # === Méthodes de classe ===

  # Regroupe une collection de tags par type, dans l'ordre de TAG_TYPE_LABELS.
  # Un tag sans type est rattaché au groupe "autre" pour ne jamais être masqué.
  # Retourne un tableau de [clé_type, libellé, tags] en ignorant les groupes vides.
  def self.grouped_by_type(tags)
    by_type = tags.group_by { |tag| tag.tag_type || "autre" }
    TAG_TYPE_LABELS.filter_map do |key, label|
      group = by_type[key]
      [ key, label, group ] if group.present?
    end
  end

  private

  def normalize_name
    self.name = name&.strip&.downcase
  end
end
