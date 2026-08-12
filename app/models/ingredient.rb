# Représente un ingrédient utilisable dans les recettes
# Chaque ingrédient a un rayon (category), un groupe d'unités (unit_group) et une unité de base
class Ingredient < ApplicationRecord
  # === Concerns ===
  include AttributeCleaner
  # Libellés français des enums (rayon, groupe d'unités) : Ingredient.enum_label,
  # .enum_options pour les sélecteurs — le français vit dans config/locales/fr.yml
  include EnumLabels

  # === Enums ===

  # Rayons de supermarché (catégories d'ingrédients)
  enum :category, {
    fruits_legumes: 0,
    boucherie_viande: 1,
    charcuterie_traiteur: 2,
    poissonnerie: 3,
    fromagerie_coupe: 4,
    boulangerie_patisserie: 5,
    produits_laitiers: 6,
    produits_frais_libre_service: 7,
    glaces_desserts_glaces: 8,
    legumes_surgeles: 9,
    viandes_poissons_surgeles: 10,
    produits_aperitifs_surgeles: 11,
    epicerie_salee: 12,
    epicerie_sucree: 13,
    boissons: 14,
    petit_dejeuner: 15,
    produits_monde: 16,
    hygiene_beaute: 17,
    entretien_maison: 18,
    papeterie_fournitures: 19,
    autre: 20
  }, prefix: true

  # Groupes d'unités de mesure (unité de base associée dans BASE_UNITS)
  enum :unit_group, {
    mass: 0,
    volume: 1,
    count: 2,
    spoon: 3
  }, prefix: true

  # === Constantes ===

  # Unité de base attendue pour chaque groupe d'unités.
  # Source de vérité unique : la validation ci-dessous et le formulaire
  # (contrôleur Stimulus `ingredient-form`, alimenté par les partials) lisent
  # tous cette table. Ajouter un groupe d'unités ne demande donc de toucher que
  # l'enum ci-dessus et cette constante.
  BASE_UNITS = {
    "mass" => "g",
    "volume" => "ml",
    "count" => "piece",
    "spoon" => "cac"
  }.freeze

  # === Associations ===
  has_many :preparations, dependent: :restrict_with_error
  has_many :recipes, through: :preparations

  # === Validations ===

  validates :name, presence: { message: "ne peut pas être vide" },
                   uniqueness: {
                     case_sensitive: false,
                     message: "existe déjà"
                   }
  validates :category, presence: { message: "doit être sélectionnée" }
  validates :unit_group, presence: { message: "doit être sélectionné" }
  validates :base_unit, presence: { message: "ne peut pas être vide" }

  # Validation du format de base_unit selon le unit_group
  validate :base_unit_matches_unit_group

  # Poids d'une pièce, facultatif : il ne se renseigne que là où l'ingrédient se
  # dit dans les deux langues (une aubergine pèse 300 g), et sert alors de pont
  # entre les recettes qui comptent et le catalogue qui pèse.
  validates :piece_weight_g,
            numericality: { greater_than: 0, message: "doit être supérieur à 0" },
            allow_nil: true
  validate :piece_weight_only_for_countable_or_weighable

  # Validation des season_months (doivent être entre 1 et 12)
  validate :valid_season_months

  # === Scopes ===

  scope :by_category, ->(category) { where(category: category) }
  scope :by_unit_group, ->(unit_group) { where(unit_group: unit_group) }
  scope :alphabetical, -> { order(:name) }

  # Filtrage par mois de saison (ingrédients disponibles dans un mois donné)
  scope :in_season_for_month, ->(month) {
    return all if month.blank?

    where("season_months @> ARRAY[?]::integer[]", month.to_i)
  }

  # Recherche par nom (fragment) ou par alias (exact).
  # L'alias part en JSON tel quel : le passer par sanitize_sql_like y laisserait
  # les échappements du LIKE, et `@>` ne trouverait plus jamais rien.
  scope :search, ->(query) {
    return all if query.blank?

    normalized = query.to_s.downcase.strip
    where("LOWER(name) LIKE :query OR aliases @> :json_query",
          query: "%#{sanitize_sql_like(normalized)}%",
          json_query: [ normalized ].to_json)
  }

  # === Méthodes publiques ===

  # Retourne le nom complet avec les alias entre parenthèses
  def display_name
    return name if aliases.blank?

    alias_list = aliases.is_a?(Array) ? aliases.join(", ") : aliases.values.join(", ")
    "#{name} (#{alias_list})"
  end

  private

  # Valide que base_unit est bien l'unité de base du unit_group (cf. BASE_UNITS)
  def base_unit_matches_unit_group
    return if unit_group.blank? || base_unit.blank?

    expected_unit = BASE_UNITS[unit_group]
    return if base_unit == expected_unit

    errors.add(:base_unit, "doit être #{expected_unit} pour le groupe #{unit_group}")
  end

  # Le poids d'une pièce ne relie que la masse et le compte. Sur un ingrédient
  # en ml ou en cuillères, il n'aurait aucun sens à la conversion — mieux vaut
  # le refuser à la saisie que le laisser dormir dans la base sans effet.
  def piece_weight_only_for_countable_or_weighable
    return if piece_weight_g.blank? || unit_group_mass? || unit_group_count?

    errors.add(:piece_weight_g, "ne s'applique qu'aux ingrédients en masse ou en pièces")
  end

  # Valide que tous les season_months sont entre 1 et 12
  def valid_season_months
    return if season_months.blank?

    invalid_months = season_months.reject { |m| m.between?(1, 12) }
    if invalid_months.any?
      errors.add(:season_months, "contient des mois invalides: #{invalid_months.join(', ')}")
    end
  end
end
