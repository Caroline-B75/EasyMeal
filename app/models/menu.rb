# frozen_string_literal: true

# Représente un menu planifié contenant plusieurs recettes.
# Un menu commence toujours en statut :draft (brouillon persisté en base)
# et passe en :active lors de la confirmation, ce qui déclenche
# la génération de la liste de courses.
#
# Architecture : le draft n'est PAS stocké en session — c'est un enregistrement
# DB standard. La différence draft/actif est uniquement portée par l'enum status.
class Menu < ApplicationRecord
  # === Associations ===
  belongs_to :user

  # Repas du menu avec leur nombre de personnes propre
  has_many :menu_recipes, dependent: :destroy
  has_many :recipes, through: :menu_recipes

  # Lignes de la liste de courses (générées + manuelles)
  has_many :grocery_items, dependent: :destroy

  # Nom donné à un menu créé sans nom — par la génération, par le démarrage
  # depuis le catalogue, et annoncé en placeholder du formulaire. Une seule
  # source : le nom promis à l'utilisatrice est exactement celui qu'elle obtient.
  # @return [String] ex. « Menu du 08/08/2026 »
  def self.default_name
    "Menu du #{Date.current.strftime('%d/%m/%Y')}"
  end

  # === Enums ===

  # Cycle de vie du menu
  # draft    : en cours de composition — modifiable librement
  # active   : finalisé — liste de courses générée (un seul par utilisateur)
  # archived : ancien menu actif, conservé dans l'historique
  enum :status, { draft: 0, active: 1, archived: 2 }, prefix: true

  # Régime alimentaire du menu (aligné avec Recipe.diet et User.default_diet)
  enum :diet, {
    omnivore: 0,
    vegetarien: 1,
    vegan: 2,
    pescetarien: 3
  }, prefix: true

  # === Validations ===
  validates :name, presence: { message: "ne peut pas être vide" },
                   length: { maximum: 100, message: "ne doit pas dépasser 100 caractères" }

  validates :default_people, numericality: {
    only_integer: true,
    greater_than_or_equal_to: 1,
    message: "doit être au moins 1"
  }

  validates :user_id, uniqueness: {
    conditions: -> { where(status: statuses[:draft]) },
    message: "a déjà un menu à valider"
  }, if: :status_draft?

  # === Scopes ===
  # Les filtres par statut passent par les scopes de l'enum (status_draft,
  # status_active, status_archived) — sauf active_menus, dont le nom explicite
  # se lit mieux sur les appels « le menu actif de l'utilisatrice ».

  # Menus finalisés (un seul actif par utilisateur)
  scope :active_menus, -> { where(status: :active) }

  # Tri chronologique (les plus récents d'abord)
  scope :recent, -> { order(created_at: :desc) }

  # === Méthodes d'instance ===

  # Passe le menu en statut :active et déclenche la génération de la liste de courses.
  # Archive automatiquement l'éventuel menu actif précédent de l'utilisateur.
  # Lève une ActiveRecord::RecordInvalid si le menu ne peut pas être activé.
  def activate!
    transaction do
      archive_current_active!
      update!(status: :active)
      Groceries::BuildForMenuService.call(menu: self)
    end
  end

  # Réactive un menu archivé : l'ancien menu actif passe en archived,
  # celui-ci redevient le menu actif et sa liste de courses est régénérée.
  def reactivate!
    raise "Seul un menu archivé peut être réactivé" unless status_archived?

    # Les coches de ce vieux menu sont obsolètes (courses d'il y a des semaines) :
    # on repart d'une liste fraîche, entièrement décochée et sans badge résiduel.
    # update_all est sûr ici : on ne fait que décocher (le callback d'effacement de
    # previous_quantity_base ne concerne que le passage à coché) et on remet
    # explicitement previous_quantity_base à nil dans la même opération.
    grocery_items.update_all(checked: false, previous_quantity_base: nil)
    activate!
  end

  # Repasse un menu actif en brouillon pour le rendre à nouveau modifiable (R3.2bis).
  # Les grocery_items sont CONSERVÉS tels quels (coches comprises) : c'est la
  # réconciliation de Groceries::BuildForMenuService, à la revalidation, qui les
  # mettra à jour sans perdre le travail de courses déjà fait.
  # Remplace l'éventuel brouillon existant : un utilisateur ne garde qu'un seul
  # menu à valider pour éviter toute ambiguïté entre menu actif et prochain menu.
  # Lève une erreur si le menu n'est pas actif.
  def revert_to_draft!
    raise "Seul un menu actif peut repasser en brouillon" unless status_active?

    transaction do
      destroy_other_drafts!
      update!(status: :draft)
    end
  end

  # Passe le menu en statut :archived (historique)
  def archive!
    update!(status: :archived)
  end

  # Nombre de recettes dans ce menu
  def recipes_count
    menu_recipes.count
  end

  # Repas prêts pour l'affichage des vues brouillon / actif : ordonnés par
  # position, photo préchargée. Chargement partagé entre la page du menu et
  # les Turbo Streams qui re-rendent ses cartes.
  def meals_for_display
    menu_recipes.includes(recipe: :photo_attachment).by_position
  end

  # Ajoute un repas à la suite du dernier de la grille — la place de tout ajout
  # dans un brouillon, qu'il vienne du catalogue ou des steppers du panneau de
  # réglages. Le nombre de personnes du menu s'applique, comme à la génération.
  # @param recipe [Recipe]
  # @param meal_type [String, nil] moment du repas ; nil hors contexte de moment
  # @return [MenuRecipe]
  def append_meal!(recipe:, meal_type: nil)
    menu_recipes.create!(recipe:           recipe,
                         meal_type:        meal_type,
                         number_of_people: default_people,
                         position:         menu_recipes.maximum(:position).to_i + 1)
  end

  # Progression de la liste de courses : articles cochés sur total.
  # `checked` est une colonne booléenne et `count` renvoie un Integer,
  # donc percent est calculé sans risque de division sur nil.
  # @return [Hash] { checked: Integer, total: Integer, percent: Integer }
  #                percent vaut 0 si la liste est vide (aucun article).
  def grocery_progress
    total = grocery_items.count
    checked = grocery_items.checked.count
    percent = total.zero? ? 0 : (checked.to_f / total * 100).round
    { checked: checked, total: total, percent: percent }
  end

  # Un brouillon avec une liste existante provient d'un menu actif repassé en
  # modification : sa validation mettra à jour la liste plutôt que d'en créer une
  # première version.
  def pending_revalidation?
    status_draft? && grocery_items.exists?
  end

  # La commande passée à la génération (UC7), sous forme d'objet-valeur.
  # La colonne jsonb requested_meal_counts n'est qu'un support de stockage —
  # même principe que User#preferred_meal_counts.
  # @return [MealCounts]
  def requested_counts
    MealCounts.from_hash(requested_meal_counts)
  end

  # La composition RÉELLE du menu, moment par moment (UC7) — par opposition à
  # la commande (requested_counts) : ce que la grille contient vraiment.
  # Comptage brut et non MealCounts, qui borne et élague les quotas d'une
  # commande : les steppers du panneau de réglages doivent afficher les cinq
  # moments, zéros compris, et dire la vérité même au-delà de MealCounts::MAX.
  # @param meals [Enumerable<MenuRecipe>] repas à compter — par défaut
  #   l'association, mais la vue du brouillon passe la collection qu'elle a
  #   déjà chargée pour éviter une requête doublon
  # @return [Hash{String => Integer}] les cinq moments, dans l'ordre de la journée
  def composed_meal_counts(meals = menu_recipes)
    tally = meals.map(&:display_meal_type).tally

    MealTypes::MEAL_TYPES.index_with { |meal_type| tally.fetch(meal_type, 0) }
  end

  # Les manques par moment (UC7) : ce que la commande demandait, moins ce que
  # le menu contient — « Il manque 3 petits-déjeuners ». Un moment servi
  # au-delà de sa commande n'est pas un manque, et un menu d'avant les quotas
  # (commande vide) n'en a aucun.
  # @param meals [Enumerable<MenuRecipe>] voir composed_meal_counts
  # @return [Hash{String => Integer}] moments incomplets seuls, dans l'ordre
  #   de la journée
  def missing_meal_counts(meals = menu_recipes)
    requested = requested_counts

    composed_meal_counts(meals).each_with_object({}) do |(meal_type, count), missing|
      gap = requested[meal_type] - count
      missing[meal_type] = gap if gap.positive?
    end
  end

  private

  # Archive le menu actif actuel de l'utilisateur (s'il existe)
  def archive_current_active!
    user.menus.active_menus.where.not(id: id).find_each(&:archive!)
  end

  def destroy_other_drafts!
    user.menus.status_draft.where.not(id: id).find_each(&:destroy!)
  end
end
