# frozen_string_literal: true

# Représente une ligne de la liste de courses d'un menu.
#
# Deux origines possibles :
# - :generated → calculé automatiquement depuis les recettes du menu (via Groceries::BuildForMenuService)
#                Recréé à chaque appel du service (idempotent).
# - :manual    → ajouté manuellement par l'utilisateur.
#                Jamais supprimé lors d'une régénération.
#
# Les quantités sont toujours stockées en unité de base (g, ml, piece, cac)
# et humanisées à l'affichage via Quantities::HumanizeService.
class GroceryItem < ApplicationRecord
  # === Concerns ===
  # Comment cette ligne se compte à l'achat. Les quatre attributs qu'il demande
  # sont recopiés depuis l'ingrédient à la génération, comme le nom et l'unité.
  include PieceCounting

  # === Associations ===
  belongs_to :menu
  # ingredient_id nullable : null si ligne custom sans ingrédient enregistré en base
  belongs_to :ingredient, optional: true

  # === Enums ===

  # Origine de la ligne : générée automatiquement ou ajoutée manuellement
  enum :source, { generated: 0, manual: 1 }, prefix: true

  # Groupe d'unités — dupliqué depuis Ingredient pour éviter la jointure à l'affichage
  enum :unit_group, { mass: 0, volume: 1, count: 2, spoon: 3 }, prefix: true

  # Rayon de supermarché — dupliqué depuis Ingredient (même mapping)
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
    fruits_surgeles: 10,
    viandes_poissons_surgeles: 11,
    produits_aperitifs_surgeles: 12,
    epicerie_salee: 13,
    epicerie_sucree: 14,
    boissons: 15,
    petit_dejeuner: 16,
    produits_monde: 17,
    hygiene_beaute: 18,
    entretien_maison: 19,
    papeterie_fournitures: 20,
    autre: 21
  }, prefix: true

  # === Callbacks ===
  before_validation :derive_unit_group_from_base_unit
  before_save :clear_previous_quantity_on_check

  # === Validations ===
  validates :name, presence: { message: "ne peut pas être vide" }

  validates :quantity_base, presence: true,
                            numericality: {
                              greater_than: 0,
                              message: "doit être supérieure à 0"
                            }

  validates :unit_group, presence: { message: "doit être renseigné" }
  validates :base_unit,  presence: { message: "ne peut pas être vide" }

  # === Scopes ===

  # Items générés automatiquement (recalculés lors des régénérations)
  scope :generated, -> { where(source: :generated) }

  # Items ajoutés manuellement (conservés lors des régénérations)
  scope :manual, -> { where(source: :manual) }

  # Items cochés (déjà achetés)
  scope :checked, -> { where(checked: true) }

  # Items non cochés (reste à acheter)
  scope :unchecked, -> { where(checked: false) }

  # Groupement par rayon (catégorie d'ingrédient)
  # La colonne category est dupliquée depuis ingredient pour éviter la jointure
  scope :by_category, ->(cat) { where(category: cat) }

  # Tri : par rayon, non-cochés en premier, puis alphabétique par nom
  scope :sorted, -> { order(:category, :checked, :name) }

  # === Méthodes privées ===
  private

  UNIT_GROUP_MAP = {
    "g"     => :mass,
    "kg"    => :mass,
    "ml"    => :volume,
    "l"     => :volume,
    "piece" => :count,
    "cac"   => :spoon,
    "cas"   => :spoon
  }.freeze

  def derive_unit_group_from_base_unit
    self.unit_group = UNIT_GROUP_MAP[base_unit] if base_unit.present?
  end

  # Efface la trace de l'ancienne quantité (badge « Était X ») dès que l'utilisateur
  # RE-COCHE l'article : cocher = « j'ai bien racheté la nouvelle quantité ».
  # Placé dans le modèle pour couvrir tous les chemins (toggle ET édition de quantité
  # passent par GroceryItemsController#update).
  def clear_previous_quantity_on_check
    self.previous_quantity_base = nil if checked? && will_save_change_to_checked?
  end

  # Formate une quantité en unité de base pour un affichage humain (virgule FR, unités).
  # Partagé par quantity_display et previous_quantity_display (DRY).
  #
  # Ce qui s'achète à la pièce se dit d'abord en pièces — c'est ainsi qu'on
  # remplit un caddie —, la mesure suivant entre parenthèses ou après un
  # « pour » selon qu'elle tombe juste (cf. PieceUnit). Tout le reste se pèse,
  # comme avant.
  #
  # @param value [Numeric, nil] quantité en unité de base
  # @return [String] Ex: "3 kg", "2 pièces (600 g)", "1 brique pour 3 ml", "6"
  def format_quantity(value)
    piece_unit&.sentence_for(value) ||
      Quantities::HumanizeService.call(quantity: value, unit_group: unit_group)[:display]
  end

  public

  # === Méthodes d'instance ===

  # Quantité humanisée pour l'affichage (ne pas stocker, toujours calculé)
  # @return [String] Ex: "3 kg", "1 càs 2 càc", "6"
  def quantity_display
    format_quantity(quantity_base)
  end

  # Ancienne quantité humanisée, pour le badge « Était X — déjà acheté ? »
  # Renseignée uniquement quand une réconciliation a augmenté la quantité d'un item coché.
  # @return [String]
  def previous_quantity_display
    format_quantity(previous_quantity_base)
  end
end
