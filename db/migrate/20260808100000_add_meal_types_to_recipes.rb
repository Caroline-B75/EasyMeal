# frozen_string_literal: true

# UC7 — Chapitre 1 : chaque recette annonce son ou ses moments de repas.
#
# Colonne array PostgreSQL, même idiome que ingredients.season_months :
# NOT NULL avec default [], pour n'avoir jamais à distinguer côté Ruby
# « aucun moment coché » de « colonne jamais renseignée ».
#
# up/down explicites plutôt que change : le backfill SQL n'est pas auto-réversible.
class AddMealTypesToRecipes < ActiveRecord::Migration[7.2]
  def up
    add_column :recipes, :meal_types, :string, array: true, default: [], null: false

    # Backfill : les recettes déjà en catalogue sont, dans leur écrasante majorité,
    # des plats. On affinera à la main depuis la fiche recette.
    # SQL brut plutôt que le modèle Recipe : une migration ne doit pas dépendre
    # du code applicatif, qui aura changé quand elle sera rejouée.
    execute <<~SQL.squish
      UPDATE recipes SET meal_types = ARRAY['lunch', 'dinner']::varchar[]
    SQL

    # GIN est le seul type d'index qu'un opérateur de conteneance (meal_types @> ARRAY[…])
    # sait exploiter — même traitement que index_ingredients_on_season_months.
    add_index :recipes, :meal_types, using: :gin, name: "index_recipes_on_meal_types"
  end

  def down
    remove_index :recipes, name: "index_recipes_on_meal_types"
    remove_column :recipes, :meal_types
  end
end
