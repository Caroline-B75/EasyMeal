# frozen_string_literal: true

# Insère le rayon « Fruits surgelés » entre les légumes surgelés et les viandes
# et poissons surgelés.
#
# La valeur entière d'un rayon n'est pas qu'un identifiant : la liste de courses
# se trie dessus (GroceryItem.sorted → order(:category, …)), et cet ordre est
# celui du parcours en magasin. Ajouter le nouveau rayon en fin d'énumération
# l'aurait affiché après « Autre », à l'autre bout de la liste, alors qu'on prend
# les fruits surgelés dans le même bac que les légumes.
#
# D'où la renumérotation : tout ce qui suivait recule d'un cran, dans les deux
# tables qui portent ce rayon (ingredients, et grocery_items où il est recopié
# pour éviter une jointure à l'affichage).
class InsertFruitsSurgelesCategory < ActiveRecord::Migration[7.2]
  # Premier rang libéré pour le nouveau rayon : l'ancien viandes_poissons_surgeles.
  INSERTED_AT = 10

  # Rangs occupés après le point d'insertion, avant celle-ci (l'ancien « autre »).
  LAST_EXISTING = 20

  TABLES = %w[ingredients grocery_items].freeze

  def up
    shift(low: INSERTED_AT, high: LAST_EXISTING, by: 1)
  end

  def down
    # Le rayon disparaît : ce qu'il contenait retombe dans les légumes surgelés,
    # faute de mieux — sans quoi la colonne porterait un rang qui n'existe plus.
    TABLES.each do |table|
      execute("UPDATE #{table} SET category = 9 WHERE category = #{INSERTED_AT}")
    end
    shift(low: INSERTED_AT + 1, high: LAST_EXISTING + 1, by: -1)
  end

  private

  # Décale d'un cran les rangs de l'intervalle [low, high]. L'ordre de parcours
  # suit le sens du décalage — du plus haut quand on avance, du plus bas quand on
  # recule : dans l'autre sens, chaque UPDATE écraserait le rang que le suivant
  # doit encore lire.
  def shift(low:, high:, by:)
    range = by.positive? ? high.downto(low) : low.upto(high)

    range.each do |rank|
      TABLES.each do |table|
        execute("UPDATE #{table} SET category = #{rank + by} WHERE category = #{rank}")
      end
    end
  end
end
