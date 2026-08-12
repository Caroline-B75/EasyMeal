# frozen_string_literal: true

# Le pont entre les deux façons de parler d'un même ingrédient : la recette le
# compte (« 2 tranches de jambon », « 1 aubergine »), le catalogue et la liste
# de courses le pèsent. Sans ce poids, une quantité comptée retombait telle
# quelle dans l'unité de base — 2 tranches de jambon devenaient 2 g.
#
# Nullable à dessein : la plupart des ingrédients n'ont pas de « pièce »
# (farine, lait, sel). L'absence de poids n'est pas une donnée manquante, c'est
# l'information qu'aucune conversion pièce ↔ masse n'a de sens pour celui-ci.
class AddPieceWeightToIngredients < ActiveRecord::Migration[7.2]
  def change
    add_column :ingredients, :piece_weight_g, :decimal, precision: 8, scale: 2
  end
end
