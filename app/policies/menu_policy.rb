# frozen_string_literal: true

# Policy pour les menus (UC1, UC2, UC3).
#
# Règles :
# - Créer un menu : tout utilisateur connecté.
# - Toutes les autres actions (show, edit, update, destroy, activate,
#   add_random_meal, replace_meal, regenerate_grocery) :
#   utilisateur connecté ET propriétaire du menu.
# - Scope : un utilisateur ne voit que ses propres menus.
class MenuPolicy < ApplicationPolicy
  # Tout utilisateur connecté peut lister ses propres menus
  def index?
    user.present?
  end

  # Tout utilisateur connecté peut créer un menu
  def create?
    user.present?
  end

  def new?
    create?
  end

  # L'utilisateur peut voir son propre menu
  def show?
    owner?
  end

  # L'utilisateur peut modifier son propre menu
  def update?
    owner?
  end

  def edit?
    update?
  end

  # L'utilisateur peut supprimer son propre menu
  def destroy?
    owner?
  end

  # Activation du menu (draft → active) — UC1
  def activate?
    owner?
  end

  # Ajout d'un repas aléatoire — UC1/UC2
  def add_random_meal?
    owner?
  end

  # Remplacement d'un repas — UC2
  def replace_meal?
    owner?
  end

  # Régénération de la liste de courses — UC2/UC3
  def regenerate_grocery?
    owner?
  end

  # Réactivation d'un menu archivé (devient le nouveau menu actif)
  def reactivate?
    owner?
  end

  # Scope : un utilisateur ne voit que ses propres menus
  class Scope < ApplicationPolicy::Scope
    def resolve
      scope.where(user: user)
    end
  end

  private

  def owner?
    user.present? && record.user_id == user.id
  end
end
