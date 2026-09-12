# Représente une recette de cuisine avec ses ingrédients, temps de préparation, difficulté, etc.
# Une recette peut avoir plusieurs ingrédients (via preparations) et être dans plusieurs menus
class Recipe < ApplicationRecord
  # === Concerns ===
  # Moments du repas : vocabulaire partagé, validations et scope de filtre
  include HasMealTypes
  # Normalise meal_types avant validation (cases à cocher → array propre)
  include AttributeCleaner
  # Libellés français des enums (régime, difficulté, budget) : Recipe.enum_label,
  # .enum_options pour les sélecteurs, human_enum_value pour une recette donnée
  include EnumLabels
  # Plafonds Cloudinary (format, poids, définition) sur les photos déposées
  include PhotoLimits
  # Trace de l'import IA : page d'origine, photo conservée (exige PhotoLimits)
  include ImportSource
  # Liste d'ingrédients : association, saisie imbriquée, et les deux règles
  # qu'elle doit respecter (au moins un ingrédient, une seule ligne par ingrédient)
  include HasIngredientList

  # === Associations ===
  has_many :recipe_tags, dependent: :destroy
  has_many :tags, through: :recipe_tags
  has_many :favorite_recipes, dependent: :destroy
  has_many :favorited_by_users, through: :favorite_recipes, source: :user
  has_many :reviews, dependent: :destroy

  # Les tentatives d'import qui ont produit cette recette. Une seule en
  # pratique, mais la colonne recipe_id n'est pas unique : has_many garantit
  # qu'aucune trace ne reste accrochée derrière la clé étrangère. Un import
  # perd son objet en même temps que sa recette — sa page d'attente n'aurait
  # plus où emmener — il part donc avec elle plutôt que de survivre orphelin.
  has_many :recipe_imports, dependent: :destroy

  # Menus contenant cette recette
  has_many :menu_recipes, dependent: :destroy
  has_many :menus, through: :menu_recipes

  # Photo de la recette via ActiveStorage
  has_one_attached :photo

  # La pièce jointe de la source d'import (source_photo) est portée par le
  # concern ImportSource, avec les prédicats qui l'interrogent.

  # Nom de remplacement attribué à un brouillon dont l'IA n'a pas extrait de titre.
  # Sert aussi de sentinelle pour détecter un titre encore à compléter (cf. draft_missing_fields).
  PLACEHOLDER_NAME = "Recette sans titre".freeze

  # === Enums ===

  # Statut de publication (draft = importé IA en attente de validation, published = visible)
  enum :status, { draft: 0, published: 1 }, default: :published

  # Régimes alimentaires (aligné avec UC1 et User.default_diet)
  enum :diet, {
    omnivore: 0,
    vegetarien: 1,
    vegan: 2,
    pescetarien: 3
  }, prefix: true

  # Hiérarchie d'inclusion des régimes :
  # vegan ⊂ végétarien ⊂ omnivore ; pescétarien ⊂ omnivore
  # Utilisé par Recipe.compatible_with(diet) pour les pools de génération de menu
  DIET_COMPATIBILITY = {
    "omnivore"    => %w[omnivore vegetarien vegan pescetarien],
    "pescetarien" => %w[vegetarien vegan pescetarien],
    "vegetarien"  => %w[vegetarien vegan],
    "vegan"       => %w[vegan]
  }.freeze

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

  # Les règles sur meal_types (au moins un moment, vocabulaire fermé) sont
  # portées par le concern HasMealTypes.

  # Photo du plat. La photo d'import passe par les mêmes plafonds Cloudinary,
  # déclarés avec elle dans ImportSource.
  validates_photos :photo

  # Les règles sur la liste d'ingrédients (au moins un ingrédient, une seule
  # ligne par ingrédient) sont portées par le concern HasIngredientList.

  # === Scopes ===

  # Filtres par statut de publication
  scope :published, -> { where(status: :published) }
  scope :draft, -> { where(status: :draft) }

  # Recherche par nom, tags ou ingrédients
  scope :search, ->(query) {
    return all if query.blank?

    left_joins(:tags, :ingredients)
      .where("recipes.name ILIKE ? OR tags.name ILIKE ? OR ingredients.name ILIKE ?",
             "%#{query}%", "%#{query}%", "%#{query}%")
      .distinct
  }

  # Filtre compatible avec la hiérarchie des régimes (UC1/UC2)
  # Ex : compatible_with(:vegetarien) inclut aussi les recettes vegan
  # À utiliser TOUJOURS à la place de .where(diet: ...) pour les pools de menu
  scope :compatible_with, ->(diet) {
    where(diet: DIET_COMPATIBILITY.fetch(diet.to_s, [ diet.to_s ]))
  }

  # Filtrer par régime exact (usage catalogue/filtre UI uniquement)
  scope :for_diet, ->(diet_value) { where(diet: diet_value) if diet_value.present? }

  # Filtrer par difficulté
  scope :by_difficulty, ->(difficulty_value) { where(difficulty: difficulty_value) if difficulty_value.present? }

  # Le scope for_meal_type est fourni par le concern HasMealTypes.

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

  # Champs essentiels encore manquants sur un brouillon importé, à compléter
  # avant validation. Retourne la liste des libellés (vide ⇒ prêt à valider).
  # Utilisé par la liste des brouillons pour prioriser ce qui reste à faire.
  def draft_missing_fields
    missing = []
    missing << "Titre"           if name.blank? || name == PLACEHOLDER_NAME
    missing << "Ingrédients"     if preparations.empty?
    missing << "Instructions"    if instructions.blank?
    missing << "Moment du repas" if meal_types.blank?
    missing
  end

  # Un brouillon est prêt à valider lorsqu'il ne manque aucun champ essentiel.
  def draft_ready?
    draft_missing_fields.empty?
  end

  # Vérifie si la recette est de saison pour un mois donné
  # Utilise le champ season_months (integer[]) de chaque ingrédient
  def seasonal_for_month?(month)
    ingredients.any? { |ingredient| ingredient.season_months&.include?(month.to_i) }
  end

  # Note moyenne des avis (arrondi à 1 décimale)
  # Utilise la collection en mémoire si déjà chargée (includes), sinon SQL AVG.
  def rating_avg
    if reviews.loaded?
      return 0 if reviews.empty?
      (reviews.sum(&:rating).to_f / reviews.size).round(1)
    else
      reviews.average(:rating)&.round(1) || 0
    end
  end

  # Nombre total d'avis
  # size utilise la collection en mémoire si chargée, COUNT SQL sinon.
  def reviews_count
    reviews.size
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
    human_enum_value(:diet, "Non renseigné")
  end

  # Nom lisible de la difficulté en français
  def difficulty_human
    human_enum_value(:difficulty, "Non renseignée")
  end

  # Nom lisible du prix en français
  def price_human
    human_enum_value(:price, "Non renseigné")
  end
end
