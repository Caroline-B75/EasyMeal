# frozen_string_literal: true

# Table de jointure entre Menu et Recipe.
# Stocke le nombre de personnes spécifique pour chaque repas du menu,
# permettant un override local du nombre de convives recette par recette.
#
# Règle : une recette ne peut apparaître qu'UNE FOIS dans un menu donné
# (contrainte DB unique sur menu_id + recipe_id + validation Rails).
class MenuRecipe < ApplicationRecord
  # === Constantes ===
  # Types de repas disponibles
  MEAL_TYPES = %w[breakfast lunch dinner snack].freeze

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

  # Unicité de la recette dans un menu (filet de sécurité côté Rails,
  # la contrainte DB unique sur menu_id+recipe_id est le vrai garde-fou)
  validates :recipe_id, uniqueness: {
    scope: :menu_id,
    message: "est déjà dans ce menu"
  }

  # === Scopes ===
  # Trie par date planifiée
  scope :chronological, -> { order(:scheduled_date, :meal_type) }

  # Filtre par type de repas
  scope :for_meal, ->(type) { where(meal_type: type) }

  # Recettes d'une date spécifique
  scope :on_date, ->(date) { where(scheduled_date: date) }

  # === Délégations ===
  delegate :name, :default_servings, to: :recipe, prefix: true

  # === Méthodes d'instance ===

  # Retourne le facteur de mise à l'échelle pour cette recette dans ce menu
  # @return [Float] Facteur multiplicateur (ex: 1.5 pour 6 personnes sur une recette de 4)
  def scale_factor
    number_of_people.to_f / recipe_default_servings
  end

  # Retourne les quantités d'ingrédients adaptées pour ce menu_recipe
  # Utilise le service ScaleService pour le calcul
  # @return [Array<Hash>] Liste des ingrédients avec leurs quantités adaptées
  def scaled_ingredients
    Quantities::ScaleService.call(recipe: recipe, servings: number_of_people)
  end

  # Libellé du type de repas en français
  # @return [String] Nom du repas traduit
  def meal_type_label
    return nil if meal_type.blank?

    I18n.t("menu_recipes.meal_types.#{meal_type}", default: meal_type.humanize)
  end

  # Affichage formaté pour l'interface
  # @return [String] Ex: "Pâtes carbonara (4 pers.)"
  def display_name
    "#{recipe_name} (#{number_of_people} pers.)"
  end
end
