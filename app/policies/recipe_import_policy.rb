class RecipeImportPolicy < ApplicationPolicy
  def new?
    user&.admin?
  end

  def create?
    user&.admin?
  end

  # La page d'attente d'un import : même porte que le formulaire. Le contrôleur
  # cherche par ailleurs l'import parmi ceux de l'utilisatrice, si bien qu'on ne
  # peut pas suivre celui de quelqu'un d'autre.
  def show?
    user&.admin?
  end
end
