# frozen_string_literal: true

# UC7 — Chasse au code mort : menu_recipes.scheduled_date n'a jamais été alimentée.
#
# Créée en février 2026 « pour un futur calendrier », aucune écriture ne l'a
# jamais renseignée : la colonne était NULL partout. Menu#next_scheduled_meal
# ne renvoyait donc jamais rien, et le bloc « Prochain : … » du tableau de bord
# ne s'affichait jamais. day_of_week (migration précédente) reprend le flambeau.
#
# L'index est retiré explicitement (PostgreSQL le supprimerait en cascade avec
# la colonne, mais l'écrire rend la migration réversible telle quelle).
class RemoveScheduledDateFromMenuRecipes < ActiveRecord::Migration[7.2]
  def change
    remove_index :menu_recipes, [ :menu_id, :scheduled_date ],
                 name: "index_menu_recipes_on_menu_id_and_scheduled_date"
    remove_column :menu_recipes, :scheduled_date, :date
  end
end
