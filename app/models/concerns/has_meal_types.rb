# frozen_string_literal: true

# Comportement du modèle qui porte un ARRAY de moments de repas (UC7).
#
# Seule Recipe l'inclut : une recette peut convenir à plusieurs moments à la fois
# (une quiche vit au déjeuner ET au dîner). MenuRecipe, qui n'en porte qu'un seul,
# se contente du vocabulaire partagé MealTypes.
#
# Prérequis du modèle hôte : une colonne array `meal_types` et un prédicat
# `draft?` (l'exemption de brouillon ci-dessous s'appuie dessus).
module HasMealTypes
  extend ActiveSupport::Concern
  include MealTypes

  included do
    # Au moins un moment annoncé — même exemption que la règle « au moins un
    # ingrédient » : un brouillon importé par IA se complète progressivement,
    # on ne le bloque pas tant qu'il n'est pas publié.
    validates :meal_types, presence: true, unless: :draft?

    # Garde-fou permanent, brouillons compris : les chips du formulaire sont
    # fermées, mais l'import IA, les seeds et la console, eux, ne le sont pas.
    validate :meal_types_must_be_known

    # Recettes qui conviennent à un moment donné (l'array le contient).
    # L'opérateur de conteneance @> est préféré à « = ANY(…) » : lui seul sait
    # exploiter l'index GIN index_recipes_on_meal_types.
    scope :for_meal_type, ->(type) {
      where("meal_types @> ARRAY[?]::varchar[]", type.to_s) if type.present?
    }
  end

  # Moments annoncés, réordonnés selon le déroulé de la journée (l'ordre en
  # base suit celui de la saisie, pas celui de l'affichage).
  def ordered_meal_types
    MealTypes::MEAL_TYPES & meal_types.to_a
  end

  private

  # Validation : tous les moments cochés appartiennent au vocabulaire connu.
  # Constante qualifiée : ActiveSupport::Concern diffère l'inclusion de MealTypes
  # jusqu'au modèle hôte, MEAL_TYPES n'est donc pas résolvable lexicalement ici.
  def meal_types_must_be_known
    unknown = meal_types.to_a - MealTypes::MEAL_TYPES
    return if unknown.empty?

    errors.add(:meal_types, "contient un moment inconnu : #{unknown.join(', ')}")
  end
end
