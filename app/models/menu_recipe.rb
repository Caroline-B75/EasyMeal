# frozen_string_literal: true

# Table de jointure entre Menu et Recipe.
# Stocke le nombre de personnes spécifique pour chaque repas du menu,
# permettant un override local du nombre de convives recette par recette.
#
# Une même recette peut apparaître PLUSIEURS FOIS dans un menu (UC7) : dans la
# vraie vie, le petit-déjeuner est souvent le même tous les matins de la semaine.
class MenuRecipe < ApplicationRecord
  # === Concerns ===
  # Fournit MEAL_TYPES, le vocabulaire partagé avec Recipe
  include MealTypes

  # === Associations ===
  belongs_to :menu
  belongs_to :recipe

  # === Validations ===
  validates :number_of_people, presence: { message: "doit être indiqué" },
                               numericality: {
                                 only_integer: true,
                                 greater_than: 0,
                                 message: "doit être un nombre entier positif"
                               }

  validates :meal_type, inclusion: { in: MEAL_TYPES, allow_blank: true }

  # day_of_week (0 = dimanche … 6 = samedi) est volontairement SANS validation :
  # le cahier des charges UC7 en fait une pure annotation, sans tri ni
  # groupement — elle ne fait que teinter la carte pour la repérer d'un coup
  # d'œil. C'est ce « rien » qui la rend sans effet de bord.

  # === Scopes ===
  # Trie par position (ordre défini par l'utilisateur via drag & drop)
  scope :by_position, -> { order(:position) }

  # Filtre par type de repas
  scope :for_meal, ->(type) { where(meal_type: type) }

  # Repas rangés sous un moment donné à l'AFFICHAGE (UC7) : ceux de ce moment,
  # plus — pour le déjeuner — les repas sans moment, que display_meal_type y
  # range déjà. C'est la contrepartie SQL de cette règle : sans elle, les
  # steppers de répartition du panneau de réglages compteraient des repas
  # qu'ils ne sauraient pas retirer.
  scope :displayed_as, lambda { |meal_type|
    if meal_type.to_s == MealCounts::UNTYPED_MEAL_TYPE
      where(meal_type: [ meal_type, nil ])
    else
      for_meal(meal_type)
    end
  }

  # === Délégations ===
  delegate :name, :default_servings, to: :recipe, prefix: true

  # === Méthodes d'instance ===

  # Retourne le facteur de mise à l'échelle pour cette recette dans ce menu
  # @return [Float] Facteur multiplicateur (ex: 1.5 pour 6 personnes sur une recette de 4)
  def scale_factor
    number_of_people.to_f / recipe_default_servings
  end

  # Moment affiché de ce repas (UC7) : le sien, ou le moment neutre des repas
  # sans moment (brouillons d'avant les quotas) — même règle que leur comptage
  # face à la commande (MealCounts::UNTYPED_MEAL_TYPE).
  # @return [String]
  def display_meal_type
    meal_type.presence || MealCounts::UNTYPED_MEAL_TYPE
  end

  # Affichage formaté pour l'interface
  # @return [String] Ex: "Pâtes carbonara (4 pers.)"
  def display_name
    "#{recipe_name} (#{number_of_people} pers.)"
  end
end
