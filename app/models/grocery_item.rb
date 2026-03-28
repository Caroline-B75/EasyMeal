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
  # === Associations ===
  belongs_to :menu
  # ingredient_id nullable : null si ligne custom sans ingrédient enregistré en base
  belongs_to :ingredient, optional: true

  # === Enums ===

  # Origine de la ligne : générée automatiquement ou ajoutée manuellement
  enum :source, { generated: 0, manual: 1 }, prefix: true

  # Groupe d'unités — dupliqué depuis Ingredient pour éviter la jointure à l'affichage
  enum :unit_group, { mass: 0, volume: 1, count: 2, spoon: 3 }, prefix: true

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

  # Tri : par rayon d'abord, puis alphabétique par nom au sein du rayon
  scope :sorted, -> { order(:category, :name) }

  # === Méthodes d'instance ===

  # Quantité humanisée pour l'affichage (ne pas stocker, toujours calculé)
  # @return [String] Ex: "3 kg", "1 càs 2 càc", "6"
  def quantity_display
    Quantities::HumanizeService.call(
      quantity: quantity_base,
      unit_group: unit_group
    )[:display]
  end
end
