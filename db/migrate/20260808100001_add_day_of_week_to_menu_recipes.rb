# frozen_string_literal: true

# UC7 — Chapitre 4 : jour de la semaine optionnel sur un repas du menu.
#
# Pure annotation (0 = dimanche … 6 = samedi, à la manière de Date#wday) :
# aucun tri, aucun groupement, aucune validation ne s'appuie dessus. La position
# manuelle reste la seule vérité d'ordre. Nullable et sans default, parce que
# « pas de jour » est l'état normal et doit le rester.
class AddDayOfWeekToMenuRecipes < ActiveRecord::Migration[7.2]
  def change
    add_column :menu_recipes, :day_of_week, :integer
  end
end
