# frozen_string_literal: true

# La date de publication d'une recette : c'est elle qui range le catalogue, les
# nouveautés en tête.
#
# Pas la date de création : une recette importée par l'IA naît en brouillon et
# peut attendre des semaines sa relecture. Publiée ce matin, elle doit
# apparaître en tête, pas à la date de son import.
#
# Les recettes déjà publiées ne savent pas quand elles l'ont été : leur date de
# création en tient lieu. Un brouillon n'a pas de date de publication, et une
# recette publiée en a toujours une — la contrainte le garantit en base.
class AddPublishedAtToRecipes < ActiveRecord::Migration[8.1]
  def up
    add_column :recipes, :published_at, :datetime
    execute("UPDATE recipes SET published_at = created_at WHERE status = 1")

    add_check_constraint :recipes, "status <> 1 OR published_at IS NOT NULL",
                         name: "recipes_published_at_when_published"
    # Sert le tri du catalogue (published_at DESC, id DESC), lu à rebours.
    add_index :recipes, [ :published_at, :id ]
  end

  def down
    remove_column :recipes, :published_at
  end
end
