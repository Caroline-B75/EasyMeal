# Policy pour la gestion des tags
# Seuls les admins peuvent gérer les tags
class TagPolicy < ApplicationPolicy
  # Admins uniquement pour toutes les actions
  def index?
    user&.admin?
  end

  def edit?
    user&.admin?
  end

  def update?
    user&.admin?
  end

  def destroy?
    user&.admin?
  end
end
