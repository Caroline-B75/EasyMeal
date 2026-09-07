# Représente un tag/label pour catégoriser les recettes
# Exemples : "salade", "équilibré", "italienne", "four", "hiver"
class Tag < ApplicationRecord
  # === Associations ===
  has_many :recipe_tags, dependent: :destroy
  has_many :recipes, through: :recipe_tags

  # === Enums ===
  # Type de tag (optionnel, pour organiser les tags par catégorie)
  enum :tag_type, {
    # Ce que le plat apporte — léger, équilibré. Rang anciennement « Régime
    # alimentaire », renommé le 05/09/2026 : le régime, c'est Recipe#diet qui le
    # dit. La rubrique décrit un profil nutritionnel, pas un régime, et pourra
    # accueillir les « sans » (gluten, lactose) le jour où ils serviront.
    nutrition: 0,
    # Le rang 1 portait la rubrique « Occasion » (apéritif, entrée, plat,
    # dessert, goûter, brunch...), retirée le 02/09/2026 : c'est le classement
    # des moments du repas (MealTypes), déjà porté par la recette elle-même — le
    # proposer aussi en tag dédoublait les filtres du catalogue. Le rang reste
    # vacant : le réattribuer ferait ressurgir ces tags sous une autre rubrique
    # (cf. la migration DeleteOccasionTags).
    methode_cuisson: 2,   # Méthode de cuisson (four, thermomix, BBQ, etc.)
    saison: 3,            # Saison (été, hiver, etc.)
    # Le rang 4 portait la rubrique « Rapidité » (rapide, express...), retirée
    # le 05/09/2026 : elle n'a jamais reçu un seul tag, le catalogue filtrant
    # déjà la durée via « Temps max » (Recipe.with_total_time_lte).
    autre: 5,             # Autre
    cuisine_monde: 6,     # Cuisine du monde (italienne, thaïlandaise, etc.)
    # Forme du plat, et elle seule : une salade reste une salade qu'on la serve
    # en entrée ou en plat. Ne pas y ranger un moment du repas — c'est
    # Recipe#meal_types qui le porte (cf. le rang 1, vacant pour cette raison).
    type_de_plat: 7       # Type de plat (salade, soupe, gratin, etc.)
  }, prefix: true

  # Libellés lisibles des types, dans l'ordre d'affichage souhaité pour l'admin.
  # L'ordre de ce hash pilote l'ordre des groupes affichés.
  TAG_TYPE_LABELS = {
    "type_de_plat"    => "Type de plat",
    "nutrition"       => "Nutrition",
    "cuisine_monde"   => "Cuisine du monde",
    "methode_cuisson" => "Méthode de cuisson",
    "saison"          => "Saison",
    "autre"           => "Autre"
  }.freeze

  # === Validations ===
  validates :name, presence: true,
                   uniqueness: { case_sensitive: false },
                   length: { minimum: 2, maximum: 50 }

  # === Scopes ===
  # Un seul scope, et il sert partout : la liste des tags est courte et toujours
  # lue en entier (liste d'administration, filtres du catalogue, formulaire de
  # recette, catalogue envoyé à l'IA). Ni recherche ni filtre par rubrique à
  # prévoir ici — c'est `grouped_by_type` qui range, en mémoire.
  scope :alphabetical, -> { order(:name) }

  # === Callbacks ===
  # Normalise le nom du tag (minuscules, trim)
  before_validation :normalize_name

  # La sidebar du catalogue lit une liste de tags mise en cache pour tout le
  # monde : sans cette invalidation, un tag supprimé restait proposé en filtre
  # — et un tag renommé y gardait son ancien nom — jusqu'à l'expiration du
  # cache, une heure plus tard.
  after_commit :expire_catalog_tags_cache

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

  def expire_catalog_tags_cache
    Recipes::CatalogQuery.expire_tags_cache!
  end
end
