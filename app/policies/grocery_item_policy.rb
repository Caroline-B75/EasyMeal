# frozen_string_literal: true

# Policy pour les GroceryItems (lignes de la liste de courses — UC3).
#
# Les membres du foyer du menu lisent et modifient sa liste de courses — tous,
# puisque chacun peut faire une partie des courses (Menu#household_member?).
#
# Ajouter un article n'ouvre aucun droit sur le catalogue : une ligne libre
# reste une ligne libre, et seul un admin crée un ingrédient (IngredientPolicy).
class GroceryItemPolicy < ApplicationPolicy
  # Afficher la liste de courses d'un menu
  def index?
    menu_household_member?
  end

  # Créer une ligne manuelle (formulaire « Ajouter un article »)
  def create?
    menu_household_member?
  end

  # Modifier une ligne (toggle checked, édition inline de la quantité)
  def update?
    menu_household_member?
  end

  # Supprimer une ligne manuelle
  def destroy?
    menu_household_member?
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      scope.joins(:menu).where(menus: { household_id: user.household_id })
    end
  end

  private

  def menu_household_member?
    record.menu.household_member?(user)
  end
end
