# frozen_string_literal: true

# Supprime les tags de l'ancienne rubrique « Occasion » (apéritif, entrée, plat,
# dessert, goûter, brunch, petit-déjeuner, salade) et leurs associations aux
# recettes.
#
# Ce classement est celui des moments du repas (MealTypes), déjà porté par la
# recette elle-même et déjà filtrable dans le catalogue via « Moment du repas » :
# la rubrique dédoublait donc les filtres. Elle disparaît de l'enum
# Tag#tag_type au même commit — sans ce nettoyage, les tags restés en base
# porteraient un rang que le modèle ne sait plus lire et se réafficheraient
# sous « Autre » au lieu de disparaître.
#
# SQL direct plutôt que Tag.destroy_all : une migration doit rester lisible par
# les versions futures du code, et le modèle ne connaît justement plus ce rang.
class DeleteOccasionTags < ActiveRecord::Migration[8.1]
  # Rang qu'occupait la rubrique dans l'enum Tag#tag_type.
  OCCASION = 1

  def up
    # Les jointures d'abord : recipe_tags.tag_id porte une clé étrangère vers tags.
    execute <<~SQL.squish
      DELETE FROM recipe_tags
      WHERE tag_id IN (SELECT id FROM tags WHERE tag_type = #{OCCASION})
    SQL

    execute "DELETE FROM tags WHERE tag_type = #{OCCASION}"
  end

  def down
    # Des tags supprimés et leur répartition sur les recettes ne se devinent pas.
    raise ActiveRecord::IrreversibleMigration
  end
end
