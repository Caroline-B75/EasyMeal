# frozen_string_literal: true

# Policy pour les menus (UC1, UC2, UC3).
#
# Règles :
# - Créer un menu : tout utilisateur connecté.
# - Toutes les autres actions (show, edit, update, destroy, activate,
#   replace_meal) :
#   utilisateur connecté ET membre du foyer du menu (Menu#household_member?).
#   Tous les membres sont égaux : aucune action n'est réservée à celui qui a
#   composé le menu.
# - Scope : un utilisateur ne voit que les menus de son foyer.
class MenuPolicy < ApplicationPolicy
  # Tout utilisateur connecté peut lister les menus de son foyer
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

  # Un membre du foyer peut voir le menu
  def show?
    household_member?
  end

  # Un membre du foyer peut modifier le menu
  def update?
    household_member?
  end

  def edit?
    update?
  end

  # Un membre du foyer peut supprimer le menu
  def destroy?
    household_member?
  end

  # Activation du menu (draft → active) — UC1
  def activate?
    household_member?
  end

  # Remplacement d'un repas — UC2
  def replace_meal?
    household_member?
  end

  # Accès à la page dédiée de la liste de courses — UC3
  def grocery?
    household_member?
  end

  # Régénération de la liste de courses — UC3
  def regenerate_grocery?
    household_member?
  end

  # Re-génération du menu brouillon avec de nouveaux paramètres — UC2
  def regenerate?
    household_member?
  end

  # Ajustement du nombre de repas d'un moment du brouillon — UC7
  def adjust_meal_count?
    household_member?
  end

  # Réactivation d'un menu archivé (devient le nouveau menu actif)
  def reactivate?
    household_member?
  end

  # Retour d'un menu actif en brouillon pour le modifier (R3.2bis)
  def revert_to_draft?
    household_member?
  end

  # Scope : un utilisateur ne voit que les menus de son foyer
  class Scope < ApplicationPolicy::Scope
    def resolve
      scope.where(household_id: user.household_id)
    end
  end

  private

  def household_member?
    record.household_member?(user)
  end
end
