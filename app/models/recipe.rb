# Représente une recette de cuisine avec ses ingrédients, temps de préparation, difficulté, etc.
# Une recette peut avoir plusieurs ingrédients (via preparations) et être dans plusieurs menus
class Recipe < ApplicationRecord
  # === Associations ===
  has_many :preparations, dependent: :destroy
  has_many :ingredients, through: :preparations
  has_many :recipe_tags, dependent: :destroy
  has_many :tags, through: :recipe_tags
  has_many :favorite_recipes, dependent: :destroy
  has_many :favorited_by_users, through: :favorite_recipes, source: :user
  has_many :reviews, dependent: :destroy

  # Menus contenant cette recette
  has_many :menu_recipes, dependent: :destroy
  has_many :menus, through: :menu_recipes

  # Photo de la recette via ActiveStorage
  has_one_attached :photo

  # Nested attributes pour créer/modifier les ingrédients via le formulaire
  accepts_nested_attributes_for :preparations,
                                allow_destroy: true,
                                reject_if: :all_blank

  # === Enums ===

  # Régimes alimentaires (aligné avec UC1 et User.default_diet)
  enum :diet, {
    omnivore: 0,
    vegetarien: 1,
    vegan: 2,
    pescetarien: 3
  }, prefix: true

  # Niveaux de difficulté
  enum :difficulty, {
    facile: 0,
    moyen: 1,
    difficile: 2
  }, prefix: true

  # Niveaux de prix
  enum :price, {
    economique: 0,
    moyen: 1,
    cher: 2
  }, prefix: true

  # === Validations ===
  validates :name, presence: true
  validates :diet, presence: true
  validates :default_servings, presence: true, numericality: { only_integer: true, greater_than: 0 }
  validates :prep_time_minutes, numericality: { only_integer: true, greater_than_or_equal_to: 0 }, allow_nil: true
  validates :cook_time_minutes, numericality: { only_integer: true, greater_than_or_equal_to: 0 }, allow_nil: true

  # Validation custom : une recette doit avoir au moins un ingrédient
  validate :must_have_at_least_one_ingredient

  # === Scopes ===

  # Recherche par nom, tags ou ingrédients
  scope :search, ->(query) {
    return all if query.blank?

    left_joins(:tags, :ingredients)
      .where("recipes.name ILIKE ? OR tags.name ILIKE ? OR ingredients.name ILIKE ?",
             "%#{query}%", "%#{query}%", "%#{query}%")
      .distinct
  }

  # Filtrer par régime
  scope :for_diet, ->(diet_value) { where(diet: diet_value) if diet_value.present? }

  # Filtrer par difficulté
  scope :by_difficulty, ->(difficulty_value) { where(difficulty: difficulty_value) if difficulty_value.present? }

  # Filtrer par temps total maximum (en minutes)
  scope :with_total_time_lte, ->(max_minutes) {
    return all if max_minutes.blank?

    where("COALESCE(prep_time_minutes, 0) + COALESCE(cook_time_minutes, 0) <= ?", max_minutes)
  }

  # Recettes de saison pour un mois donné (au moins 1 ingrédient de saison)
  scope :seasonal_for_month, ->(month) {
    return all if month.blank?

    joins(:ingredients)
      .where(":month = ANY(ingredients.season_months)", month: month.to_i)
      .distinct
  }

  # Recettes contenant certains ingrédients (par nom ou alias)
  scope :with_ingredient_names, ->(ingredient_names) {
    return all if ingredient_names.blank?

    ingredients_matching(ingredient_names).distinct
  }

  # Recettes n'utilisant PAS certains ingrédients
  scope :without_ingredient_names, ->(ingredient_names) {
    return all if ingredient_names.blank?

    where.not(id: ingredients_matching(ingredient_names).select(:id))
  }

  # Recettes ayant au moins un des tags donnés (filtre OR)
  scope :with_any_tags, ->(tag_ids) {
    return all if tag_ids.blank?

    joins(:tags).where(tags: { id: tag_ids }).distinct
  }

  # Tri alphabétique
  scope :alphabetical, -> { order(name: :asc) }

  # Requête SQL partagée : recettes dont un ingrédient correspond par nom ou alias
  def self.ingredients_matching(ingredient_names)
    joins(:ingredients)
      .where("ingredients.name ILIKE ANY(ARRAY[?]) OR ingredients.aliases ?| ARRAY[?]",
             ingredient_names.map { |ingredient_name| "%#{ingredient_name}%" },
             ingredient_names)
  end
  private_class_method :ingredients_matching

  # === Méthodes d'instance ===

  # Temps total de préparation + cuisson (en minutes)
  def total_time_minutes
    (prep_time_minutes || 0) + (cook_time_minutes || 0)
  end

  # Vérifie si la recette est de saison pour un mois donné
  def seasonal_for_month?(month)
    ingredients.any? { |ingredient| ingredient.in_season_for_month?(month) }
  end

  # Note moyenne des avis (arrondi à 1 décimale)
  def rating_avg
    reviews.average(:rating)&.round(1) || 0
  end

  # Nombre total d'avis
  def reviews_count
    reviews.count
  end

  # Nombre de fois mise en favori
  def favorites_count
    favorite_recipes.count
  end

  # Vérifie si l'utilisateur a mis cette recette en favori
  def favorited_by?(user) # :reek:NilCheck
    return false if user.nil?
    favorite_recipes.exists?(user: user)
  end

  # Nom lisible du régime en français
  def diet_human
    I18n.t("activerecord.attributes.recipe.diets.#{diet}", default: diet.humanize)
  end

  # Nom lisible de la difficulté en français
  def difficulty_human
    human_enum_value(:difficulty, "Non renseignée")
  end

  # Nom lisible du prix en français
  def price_human
    human_enum_value(:price, "Non renseigné")
  end

  private

  # Génère le label i18n d'une valeur d'enum, avec fallback si nil
  def human_enum_value(field, nil_label) # :reek:NilCheck
    value = send(field)
    return nil_label if value.nil?

    I18n.t("activerecord.attributes.recipe.#{field.to_s.pluralize}.#{value}", default: value.humanize)
  end

  # Validation : une recette doit avoir au moins un ingrédient
  def must_have_at_least_one_ingredient
    if preparations.reject(&:marked_for_destruction?).empty?
      errors.add(:base, "Une recette doit contenir au moins un ingrédient")
    end
  end
end
