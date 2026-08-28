# Policy pour la gestion des utilisateurs
# Seuls les admins peuvent administrer les comptes.
class UserPolicy < ApplicationPolicy
  def index?
    admin?
  end

  def edit?
    admin?
  end

  def update?
    admin?
  end

  def destroy?
    admin?
  end

  private

  def admin?
    user&.admin?
  end
end
