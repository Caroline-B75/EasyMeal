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

    activate!
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

  private

  # Archive le menu actif actuel de l'utilisateur (s'il existe)
  def archive_current_active!
    user.menus.active_menus.where.not(id: id).find_each(&:archive!)
  end
end
