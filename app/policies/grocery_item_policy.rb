# frozen_string_literal: true

# Policy pour les GroceryItems (lignes de la liste de courses — UC3).
#
# Seul le propriétaire du menu peut lire et modifier sa liste de courses.
#
# Ajouter un article n'ouvre aucun droit sur le catalogue : une ligne libre
# reste une ligne libre, et seul un admin crée un ingrédient (IngredientPolicy).
class GroceryItemPolicy < ApplicationPolicy
  # Afficher la liste de courses d'un menu
  def index?
    menu_owner?
  end

  # Créer une ligne manuelle (formulaire « Ajouter un article »)
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
