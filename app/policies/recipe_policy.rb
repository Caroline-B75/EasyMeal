# Policy de sécurité pour les Recipes
# Lecture publique (tout le monde peut consulter les recettes)
# Création/modification/suppression réservée aux admins (gestion du catalogue)
class RecipePolicy < ApplicationPolicy
  # Tout le monde peut voir la liste des recettes (UC5 - Catalogue)
  def index?
    true
  end

  # Tout le monde peut voir une recette (UC4 - Fiche recette)
  def show?
    true
  end

  # Seuls les admins peuvent créer une recette (gestion du catalogue)
  def create?
    user&.admin?
  end

  def new?
    create?
  end

  # Seuls les admins peuvent modifier une recette
  def update?
    user&.admin?
  end

  def edit?
    update?
  end

  # Seuls les admins peuvent supprimer une recette
  # (sauf si elle est utilisée dans des menus - géré par dependent: :restrict_with_error)
  def destroy?
    user&.admin?
  end

  # Tout utilisateur connecté peut toggle, uniquement sur les recettes publiées
  def toggle_in_draft?
    user.present? && record.published?
  end

  def toggle_favorite?
    user.present? && record.published?
  end

  # Seuls les admins peuvent importer ou publier une recette IA
  def import?
    user&.admin?
  end

  def publish?
    user&.admin?
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      # Le catalogue n'affiche que les recettes publiées pour tout le monde.
      # Les brouillons sont gérés exclusivement via /recipe_drafts.
      scope.published
    end
  end
end
