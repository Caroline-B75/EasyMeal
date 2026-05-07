# frozen_string_literal: true

# Policy pour les MenuRecipes (repas d'un menu — UC1/UC2).
#
# Délègue systématiquement à MenuPolicy du menu parent :
# seul le propriétaire du menu peut ajouter, modifier ou supprimer ses repas.
class MenuRecipePolicy < ApplicationPolicy
  # Tout utilisateur connecté peut créer un menu_recipe (ajout manuel depuis /recipes)
  # La vérification de propriété du menu est faite côté contrôleur via le menu parent
  def create?
    user.present?
  end

  # Modifier le nombre de personnes d'un repas
  def update?
    menu_owner?
  end

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
