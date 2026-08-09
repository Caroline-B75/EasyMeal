# frozen_string_literal: true

# Policy pour les MenuRecipes (repas d'un menu — UC1/UC2).
#
# Délègue systématiquement à MenuPolicy du menu parent :
# seul le propriétaire du menu peut modifier ou supprimer ses repas.
# (L'ajout passe par le catalogue — Recipes::DraftManageable — et est couvert
# par RecipePolicy#toggle_in_draft?.)
class MenuRecipePolicy < ApplicationPolicy
  # Modifier un repas (personnes, type, jour)
  def update?
    menu_owner?
  end

  # Réordonner un repas dans sa section (UC7, boutons mobiles ⬆️/⬇️) : même
  # règle que la modification.
  alias_method :move_up?, :update?
  alias_method :move_down?, :update?

  # Supprimer un repas du menu
  def destroy?
    menu_owner?
  end

  # Scope non nécessaire (les menu_recipes sont toujours accédés via @menu)
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
