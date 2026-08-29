# frozen_string_literal: true

# Le second pont entre deux façons de mesurer un même ingrédient : la recette le
# dose au volume ou à la cuillère (« 1 c. à s. de farine »), le catalogue le pèse.
# Une cuillère à soupe fait 15 ml partout — ça, Units le sait —, mais ces 15 ml
# pèsent 8 g de farine et 21 g de miel : seule la densité de l'ingrédient peut le
# dire, d'où sa place ici plutôt que dans le vocabulaire des unités.
#
# Nullable à dessein, comme piece_weight_g : l'absence de densité n'est pas une
# donnée manquante, c'est l'information qu'on refuse de convertir au hasard —
# et ce refus est justement ce qui fait apparaître l'avertissement à l'import.
#
# density_source dit d'où vient la valeur, et rien d'autre : une densité estimée
# par l'IA se signale « à vérifier » tant qu'un humain ne l'a pas confirmée. Sans
# cette provenance, une estimation fausse fausserait en silence les quantités de
# la liste de courses.
class AddDensityToIngredients < ActiveRecord::Migration[7.2]
  def change
    add_column :ingredients, :density_g_per_ml, :decimal, precision: 6, scale: 3
    add_column :ingredients, :density_source, :integer
  end
end
