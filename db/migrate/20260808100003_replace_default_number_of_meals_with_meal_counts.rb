# frozen_string_literal: true

# UC7 — chapitre 2 : on ne commande plus « 7 repas » mais une semaine décrite
# moment par moment. La préférence utilisateur suit ce changement de modèle.
#
# Pas de backfill volontaire : un nombre unique ne se répartit pas entre
# petit-déj, déjeuner, goûter, apéro et dîner sans inventer des données. Les
# utilisatrices décrivent leur semaine type une fois, via le formulaire de
# génération ou leurs préférences — c'est précisément le geste que la
# fonctionnalité rend simple.
class ReplaceDefaultNumberOfMealsWithMealCounts < ActiveRecord::Migration[7.2]
  def change
    # Répartition mémorisée : { "breakfast" => 7, …, "same_breakfast" => true }.
    # jsonb (et non un jeu de 5 colonnes) parce que le vocabulaire des moments
    # appartient au code (MealTypes), pas au schéma : en ajouter un ne devra
    # jamais coûter une migration.
    add_column :users, :default_meal_counts, :jsonb, default: {}, null: false

    # Type et options répétés : c'est ce qui rend la suppression réversible.
    remove_column :users, :default_number_of_meals, :integer, default: 7, null: false
  end
end
