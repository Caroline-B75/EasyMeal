# frozen_string_literal: true

# Une course habituelle : ce que le foyer achète chaque semaine ou presque, et
# qu'il ajoute d'un bouton à sa liste de courses (UC8, étape 3 — cf.
# docs/specs/UC8_courses_habituelles.md).
#
# Elle garde ce qui a été saisi — « 6 L » reste 6 et « l » —, pas une quantité
# de base : la conversion se fait à l'ajout, par le même chemin que le
# formulaire « Ajouter un article » (Groceries::AddManualItemService). Le rayon
# d'un article reconnu vient donc toujours du catalogue : si l'admin le change,
# les habituels suivent.
#
# Une seule liste par foyer, partagée par tous ses membres ; un article n'y
# figure qu'une fois.
class UsualGroceryItem < ApplicationRecord
  # === Concerns ===
  # « Cet article est-il déjà là ? » (scope matching_article)
  include ArticleMatching

  # === Associations ===
  belongs_to :household
  # Facultatif : le dentifrice n'est pas au catalogue
  belongs_to :ingredient, optional: true

  # === Enums ===

  # Le rayon saisi pour un article libre. Pour un article reconnu, celui de
  # l'ingrédient, recopié : c'est le rayon de repli s'il quitte le catalogue.
  # Un rayon inconnu est une erreur de saisie, pas une exception.
  enum :category, Ingredient::CATEGORIES, prefix: true, validate: { allow_nil: true }

  # === Callbacks ===
  before_validation :normalize_entry
  before_validation :recognize_ingredient, on: :create

  # === Validations ===
  validates :name, presence: { message: "ne peut pas être vide" }
  validates :quantity, numericality: { greater_than: 0, message: "doit être supérieure à 0" }
  validate :unique_in_household
  validate :unit_readable_by_ingredient

  # === Scopes ===

  # Dans l'ordre de la liste de courses : par rayon, puis par nom
  scope :sorted, -> { order(:category, :name) }

  # === Méthodes de classe ===

  # Reprend dans les habituels du foyer les ajouts ponctuels d'une liste de
  # courses : ce sont justement ceux qu'on ressaisit chaque semaine. Un article
  # déjà présent dans les habituels est ignoré (cf. unique_in_household).
  # @param menu [Menu]
  # @return [Integer] nombre d'articles repris
  def self.import_from(menu)
    menu.grocery_items.one_off.sorted.to_a.count do |line|
      menu.household.usual_grocery_items.create(entry_from(line)).persisted?
    end
  end

  # Une ligne de courses dite comme on l'aurait saisie : « 2 kg » plutôt que
  # « 2000 g ». L'écriture lisible n'est retenue que si elle tombe juste —
  # 1234 g ne deviennent pas 1,23 kg — et si son unité se saisit (ni pincée, ni
  # pièce) ; sinon la quantité reste dans l'unité de base.
  # @param line [GroceryItem]
  # @return [Hash] attributs d'une course habituelle
  def self.entry_from(line)
    readable = Quantities::HumanizeService.call(quantity: line.quantity_base, unit_group: line.unit_group)
    unit     = Units.canonical(readable[:unit])
    exact    = unit && readable[:value].to_d * Units.factor_to(unit, line.unit_group).to_d == line.quantity_base

    quantity, unit = exact ? [ readable[:value], unit ] : [ line.quantity_base, line.base_unit ]
    { name: line.name, ingredient: line.ingredient, category: line.category, quantity: quantity, unit: unit }
  end

  # === Méthodes d'instance ===

  # Ce que le formulaire « Ajouter un article » enverrait pour cet article :
  # c'est par ce chemin qu'il rejoint la liste de courses.
  # @param quantity [Numeric] la quantité de cette fois — la pop-up la laisse changer
  # @return [Hash]
  def entry(quantity = self.quantity)
    { name: name, quantity: quantity, unit: unit, category: category, ingredient_id: ingredient_id }
  end

  # L'article a-t-il déjà été ajouté à cette liste de courses ? La ligne qui le
  # désigne porte alors une part habituelle. Une requête par article : la liste
  # est courte, et la question ne se pose qu'à l'ouverture de la pop-up.
  # @param menu [Menu]
  def added_to?(menu)
    menu.grocery_items.with_usual_part.matching_article(name: name, ingredient: ingredient).exists?
  end

  # Libellé de l'unité saisie (« L », « pièce »)
  def unit_label
    Units.label(unit)
  end

  # La quantité pour un champ de saisie : « 6 » plutôt que « 6.0 »
  # @return [Integer, String]
  def quantity_for_input
    quantity.frac.zero? ? quantity.to_i : quantity.to_s("F")
  end

  private

  # Mêmes règles que l'ajout d'un article à la liste de courses : l'unité est
  # ramenée à sa forme canonique, sans unité un article se compte, sans quantité
  # il s'en achète un.
  def normalize_entry
    self.name     = name.to_s.strip
    self.unit     = Units.canonical(unit) || Units::DEFAULT_UNIT
    self.quantity = Groceries::AddManualItemService::DEFAULT_QUANTITY if quantity.nil?
  end

  # L'article est-il au catalogue ? Il en prend alors le nom et le rayon, comme
  # une ligne de courses (Ingredient.recognize).
  def recognize_ingredient
    self.ingredient = Ingredient.recognize(name: name, id: ingredient_id)
    return unless ingredient

    self.name     = ingredient.name
    self.category = ingredient.category
  end

  # Un article n'est qu'une fois dans les habituels du foyer
  def unique_in_household
    return if household.nil? || name.blank?

    twins = household.usual_grocery_items.matching_article(name: name, ingredient: ingredient).where.not(id: id)
    errors.add(:base, "« #{name} » est déjà dans tes courses habituelles.") if twins.exists?
  end

  # Un article du catalogue ne se saisit que dans une unité qu'il sait lire —
  # le sélecteur s'y restreint, ceci arrête ce qui l'aurait contourné. Même
  # contrôle qu'à l'ajout sur la liste de courses.
  def unit_readable_by_ingredient
    return if ingredient.nil? || UnitConversionService.compatible?(from_unit: unit, ingredient: ingredient)

    errors.add(:base, ingredient.unit_mismatch_message(unit))
  end
end
