# frozen_string_literal: true

# Active l'extension `unaccent`, qui ramène « épinards » et « epinards » à la
# même chaîne.
#
# Les recettes qu'on importe sont écrites par des humains pressés et relues par
# une IA : les accents y manquent une fois sur deux. Le catalogue, lui, est
# accentué correctement — « Épinards », « Bœuf haché », « Pâtes ». Sans cette
# extension, la correspondance exacte échouait sur cette seule différence et
# l'ingrédient repartait en « à préciser » alors qu'il existe.
#
# Le désaccentuage se fait à la requête (cf. IngredientMatcherService et
# Ingredient.search) plutôt qu'à l'écriture : le catalogue garde ses accents,
# qui sont ce qu'on affiche.
class EnableUnaccentExtension < ActiveRecord::Migration[7.2]
  def change
    enable_extension "unaccent"
  end
end
