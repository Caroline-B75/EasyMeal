# Représente une recette mise en favori par un utilisateur (UC4)
# Permet de retrouver rapidement ses recettes préférées
class FavoriteRecipe < ApplicationRecord
  # === Associations ===
  belongs_to :user
  belongs_to :recipe

  # === Validations ===
  # Un utilisateur ne peut mettre en favori qu'une seule fois la même recette
  validates :recipe_id, uniqueness: {
    scope: :user_id,
    message: "est déjà dans vos favoris"
  }

  # === Scopes ===
  scope :recent, -> { order(created_at: :desc) }

  # === Méthodes de classe ===

  # Toggle favori : ajoute si absent, supprime si présent
  # Retourne true si ajouté, false si supprimé
  def self.toggle_for(user:, recipe:)
    favorite = find_by(user: user, recipe: recipe)

    if favorite
      favorite.destroy
      false # Supprimé
    else
      create!(user: user, recipe: recipe)
      true # Ajouté
    end
  end
end

