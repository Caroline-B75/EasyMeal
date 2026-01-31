# frozen_string_literal: true

# Crée la table de jointure entre Menu et Recipe
# Permet de définir le nombre de personnes spécifique pour chaque recette dans un menu
# Exemple : Un même plat peut servir 4 personnes au déjeuner et 6 au dîner
class CreateMenuRecipes < ActiveRecord::Migration[7.2]
  def change
    create_table :menu_recipes do |t|
      # Le menu auquel appartient cette recette
      t.references :menu, null: false, foreign_key: true

      # La recette ajoutée au menu
      t.references :recipe, null: false, foreign_key: true

      # Nombre de personnes pour cette recette dans ce menu
      # Permet d'adapter les quantités indépendamment du default_servings de la recette
      t.integer :number_of_people, null: false

      # Moment du repas (optionnel, pour organisation)
      # Values: breakfast, lunch, dinner, snack
      t.string :meal_type

      # Date prévue pour ce repas (optionnel, pour calendrier)
      t.date :scheduled_date

      t.timestamps
    end

    # Index composé pour retrouver rapidement une recette dans un menu
    add_index :menu_recipes, [:menu_id, :recipe_id]

    # Index pour filtrer par date de planification
    add_index :menu_recipes, [:menu_id, :scheduled_date]
  end
end
