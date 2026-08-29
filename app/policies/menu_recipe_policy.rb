# frozen_string_literal: true

# Policy pour les MenuRecipes (repas d'un menu — UC1/UC2).
#
# Délègue systématiquement à MenuPolicy du menu parent :
# seul le propriétaire du menu peut modifier ou supprimer ses repas.
# (Le choix d'une recette passe par le catalogue — Recipes::DraftManageable —
# et est couvert par RecipePolicy#toggle_in_draft? ; la duplication d'un repas
# déjà placé, elle, est couverte ici.)
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

  # Dupliquer un repas (UC7) : réservé au brouillon — plus strict que les autres
  # actions. Sur un menu validé, la copie serait un repas absent de la liste de
  # courses déjà arrêtée. La carte n'y propose donc pas le bouton, et la règle
  # est rappelée ici pour une requête forgée.
  def duplicate?
    menu_owner? && record.menu.status_draft?
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
