# Représente un ingrédient utilisé dans une recette avec sa quantité
# Table de jointure entre Recipe et Ingredient avec quantité en unité de base
# Exemple : "Pâtes carbonara" utilise 200g de pâtes, 3 œufs, 100g de lardons
class Preparation < ApplicationRecord
  # === Associations ===
  belongs_to :recipe
  belongs_to :ingredient

  # === Validations ===
  validates :ingredient_id, presence: { message: "doit être sélectionné" }
  validates :quantity_base, presence: { message: "ne peut pas être vide" },
                            numericality: { greater_than: 0, message: "doit être supérieure à 0" }

  # Empêche d'ajouter 2 fois le même ingrédient dans une recette
  validates :ingredient_id, uniqueness: {
    scope: :recipe_id,
    message: "est déjà présent dans cette recette"
  }

  # === Délégations ===
  # Permet d'accéder facilement aux propriétés de l'ingrédient
  delegate :name, :unit_group, :base_unit, :category, to: :ingredient, prefix: true

  # === Méthodes d'instance ===

  # Retourne la quantité mise à l'échelle pour un nombre de personnes donné
  # @param servings [Integer] Nombre de personnes souhaité
  # @return [Float] Quantité en unité de base, adaptée au nombre de personnes
  def scaled_quantity(servings:)
    factor = servings.to_f / recipe.default_servings
    (quantity_base * factor).round(3)
  end

  # Retourne la quantité humanisée pour un nombre de personnes donné
  # Utilise le service Quantities::HumanizeService pour un affichage lisible
  # (g→kg, ml→L, càc→càs, etc.)
  #
  # @param servings [Integer] Nombre de personnes souhaité
  # @return [String] Quantité formatée avec unité (ex: "1,5 kg", "2 càs")
  def humanized_quantity(servings:)
    scaled = scaled_quantity(servings: servings)
    result = Quantities::HumanizeService.call(
      quantity: scaled,
      unit_group: ingredient_unit_group
    )
    result[:display]
  end

  # Retourne toutes les informations de quantité pour un affichage complet
  # @param servings [Integer] Nombre de personnes souhaité
  # @return [Hash] { quantity_base, quantity_display, unit, ingredient, category }
  def quantity_info(servings:)
    scaled = scaled_quantity(servings: servings)
    humanized = Quantities::HumanizeService.call(
      quantity: scaled,
      unit_group: ingredient_unit_group
    )

    {
      ingredient: ingredient,
      quantity_base: scaled,
      quantity_display: humanized[:display],
      unit: humanized[:unit],
      category: ingredient_category
    }
  end
end

