# Table de jointure entre Recipe et Tag
# Permet à une recette d'avoir plusieurs tags et un tag d'être sur plusieurs recettes
class RecipeTag < ApplicationRecord
  # === Associations ===
  belongs_to :recipe
  belongs_to :tag

  # === Validations ===
  # Empêche d'ajouter 2 fois le même tag à une recette
  validates :tag_id, uniqueness: {
    scope: :recipe_id,
    message: "est déjà associé à cette recette"
  }
end

