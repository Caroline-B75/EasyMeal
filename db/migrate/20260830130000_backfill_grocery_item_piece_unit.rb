# frozen_string_literal: true

# Les listes de courses déjà générées recopient leur ingrédient tel qu'il était
# au moment de la génération. Sans cette reprise, elles resteraient au poids
# jusqu'à la prochaine revalidation de leur menu — une liste en cours de courses
# n'aurait pas les pièces, celle d'à côté si.
#
# Seules les lignes encore reliées à un ingrédient sont concernées : une ligne
# orpheline (ingrédient retiré du catalogue, cf. dependent: :nullify) n'a plus
# de source à qui demander, et garde donc ce qu'elle affichait.
class BackfillGroceryItemPieceUnit < ActiveRecord::Migration[8.1]
  def up
    execute(<<~SQL.squish)
      UPDATE grocery_items
         SET piece_weight_g     = ingredients.piece_weight_g,
             piece_volume_ml    = ingredients.piece_volume_ml,
             piece_label        = ingredients.piece_label,
             piece_label_plural = ingredients.piece_label_plural
        FROM ingredients
       WHERE grocery_items.ingredient_id = ingredients.id
    SQL
  end

  # Les colonnes retrouvent leur état d'origine : vides.
  def down
    execute(<<~SQL.squish)
      UPDATE grocery_items
         SET piece_weight_g = NULL, piece_volume_ml = NULL,
             piece_label = NULL, piece_label_plural = NULL
    SQL
  end
end
