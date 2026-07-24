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

  # Brouillons de l'utilisateur (en cours de composition)
  scope :drafts, -> { where(status: :draft) }

  # Menus finalisés (un seul actif par utilisateur)
  scope :active_menus, -> { where(status: :active) }

  # Menus archivés (historique)
  scope :archived, -> { where(status: :archived) }

  # Brouillons inactifs depuis plus de 7 jours — candidats au nettoyage
  scope :stale_drafts, -> { draft.where("updated_at < ?", 7.days.ago) }

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

  # Nombre total de personnes servies (somme de tous les repas)
  def total_servings
    menu_recipes.sum(:number_of_people)
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

  # Prochain repas planifié à venir (date >= aujourd'hui).
  # Renvoie nil si aucun repas n'a de date planifiée (scheduled_date nullable).
  # @return [MenuRecipe, nil]
  def next_scheduled_meal
    menu_recipes.where(scheduled_date: Date.current..).order(:scheduled_date).first
  end

  # Un brouillon avec une liste existante provient d'un menu actif repassé en
  # modification : sa validation mettra à jour la liste plutôt que d'en créer une
  # première version.
  def pending_revalidation?
    status_draft? && grocery_items.exists?
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
