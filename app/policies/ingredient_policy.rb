# Policy de sécurité pour les Ingredients
# Seuls les admins peuvent créer/modifier/supprimer
# Tout le monde peut consulter (pour l'auto-complétion)
class IngredientPolicy < ApplicationPolicy
  # Tout le monde peut voir la liste des ingrédients
  def index?
    true
  end

  # Tout le monde peut voir un ingrédient
  def show?
    true
  end

  # Seuls les admins peuvent créer un ingrédient
  def create?
    user&.admin?
  end

  def new?
    create?
  end

  # Seuls les admins peuvent modifier un ingrédient
  def update?
    user&.admin?
  end

  def edit?
    update?
  end

  # Seuls les admins peuvent supprimer un ingrédient
  def destroy?
    user&.admin?
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      # Tout le monde peut voir tous les ingrédients
      scope.all
    end
  end
end
