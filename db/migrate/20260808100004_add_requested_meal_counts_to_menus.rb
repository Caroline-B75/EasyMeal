# frozen_string_literal: true

# UC7 — chapitre 3 : le moteur de génération honore une commande par moment.
# La commande passée à la génération est mémorisée sur le menu lui-même :
# c'est elle qui permet d'afficher les manques dans le brouillon
# (Menu#missing_meal_counts) et de re-générer à l'identique (changement de
# régime depuis le panneau de réglages).
class AddRequestedMealCountsToMenus < ActiveRecord::Migration[7.2]
  def change
    # Même support que users.default_meal_counts : un jsonb dont le vocabulaire
    # (MealTypes) appartient au code, pas au schéma — ajouter un moment ne
    # coûtera jamais une migration. Pas de backfill : un menu d'avant les
    # quotas n'a pas de commande, et n'affiche donc aucun manque.
    add_column :menus, :requested_meal_counts, :jsonb, default: {}, null: false
  end
end
