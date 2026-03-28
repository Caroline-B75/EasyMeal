# frozen_string_literal: true

# Policy pour les GroceryItems (lignes de la liste de courses — UC3).
#
# Délègue à MenuPolicy du menu parent :
# seul le propriétaire du menu peut lire et modifier sa liste de courses.
#
# Règle supplémentaire pour la création d'ingrédients (chemin C de la pop-up) :
# la vérification user.admin? est faite dans le contrôleur au moment
# de décider quel chemin de création emprunter (admin vs custom).
class GroceryItemPolicy < ApplicationPolicy
  # Afficher la liste de courses d'un menu
  def index?
    menu_owner?
  end

  # Créer une ligne manuelle (ajout via pop-up — chemins A, B, C)
  def create?
    menu_owner?
  end

  # Modifier une ligne (toggle checked, édition inline de la quantité)
  def update?
    menu_owner?
  end

  # Supprimer une ligne manuelle
  def destroy?
    menu_owner?
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      scope.joins(:menu).where(menus: { user: user })
    end
  end

  private

  def menu_owner?
    user.present? && record.menu.user_id == user.id
  end
end
