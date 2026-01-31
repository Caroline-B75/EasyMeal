# frozen_string_literal: true

# Représente un menu planifié contenant plusieurs recettes
# Permet de regrouper des recettes et de générer une liste de courses agrégée
#
# Exemples d'usage :
# - "Menu semaine 5" : planification hebdomadaire classique
# - "Anniversaire Marie" : événement ponctuel
# - "Batch cooking dimanche" : préparation groupée
class Menu < ApplicationRecord
  # === Associations ===
  belongs_to :user

  # Recettes incluses dans ce menu avec leurs paramètres (nombre de personnes)
  has_many :menu_recipes, dependent: :destroy
  has_many :recipes, through: :menu_recipes

  # Permet de créer/modifier les recettes du menu via un formulaire imbriqué
  accepts_nested_attributes_for :menu_recipes,
                                allow_destroy: true,
                                reject_if: :all_blank

  # === Validations ===
  validates :name, presence: { message: "ne peut pas être vide" },
                   length: { maximum: 100, message: "ne doit pas dépasser 100 caractères" }

  # === Scopes ===
  # Menus triés par date de début (les plus récents d'abord)
  scope :recent, -> { order(start_date: :desc, created_at: :desc) }

  # Menus de la semaine en cours
  scope :current_week, -> {
    week_start = Date.current.beginning_of_week
    week_end = Date.current.end_of_week
    where(start_date: week_start..week_end)
  }

  # === Méthodes d'instance ===

  # Nombre total de personnes servies par ce menu (somme de tous les repas)
  # Utile pour des statistiques ou estimations
  def total_servings
    menu_recipes.sum(:number_of_people)
  end

  # Nombre de recettes dans ce menu
  def recipes_count
    menu_recipes.count
  end

  # Retourne les informations d'ingrédients agrégées pour la liste de courses
  # Utilise le service dédié pour éviter la logique métier dans le modèle
  # @return [Array<Hash>] Liste d'ingrédients avec quantités agrégées
  def grocery_list
    Groceries::BuildForMenuService.call(menu: self)
  end
end
