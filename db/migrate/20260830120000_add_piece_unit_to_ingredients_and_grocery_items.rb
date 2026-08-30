# frozen_string_literal: true

# Comment un ingrédient se compte quand on l'achète.
#
# Le catalogue mesure ce qu'une recette consomme — 600 g d'aubergine, 3 ml de
# lait —, mais un magasin ne vend ni des grammes d'aubergine ni des millilitres
# de lait : il vend deux aubergines et une brique. Ces colonnes portent cette
# seconde façon de dire, celle des courses.
#
# `piece_label` est à la fois l'information et l'interrupteur : un ingrédient qui
# porte un nom de pièce s'affiche en pièces, un ingrédient sans nom de pièce se
# pèse. Rien d'autre ne distingue le poireau (« 3 pièces ») des olives (« 150 g »),
# et surtout pas un seuil sur le poids — le chocolat et le poireau pèsent tous
# deux 200 g la pièce et se comptent à l'opposé.
#
# `piece_label_plural` ne se renseigne que là où le français refuse le « s » :
# maquereau/maquereaux, gambas et noix invariables. Nul partout ailleurs, et
# c'est le cas courant.
#
# `piece_volume_ml` est le jumeau de piece_weight_g pour ce qui se mesure au
# volume. Même rôle exactement — la quantité que contient UNE pièce —, et les
# deux ne cohabitent jamais sur un même ingrédient : une aubergine se pèse, une
# brique de lait se verse.
#
# Les quatre colonnes sont recopiées sur grocery_items, comme le sont déjà le
# nom, le rayon et l'unité (cf. Groceries::BuildForMenuService) : une ligne de
# courses doit rester lisible après le retrait de son ingrédient du catalogue,
# et l'affichage ne doit pas payer une jointure par ligne.
class AddPieceUnitToIngredientsAndGroceryItems < ActiveRecord::Migration[8.1]
  def change
    add_column :ingredients, :piece_volume_ml,    :decimal, precision: 8, scale: 2
    add_column :ingredients, :piece_label,        :string
    add_column :ingredients, :piece_label_plural, :string

    add_column :grocery_items, :piece_weight_g,     :decimal, precision: 8, scale: 2
    add_column :grocery_items, :piece_volume_ml,    :decimal, precision: 8, scale: 2
    add_column :grocery_items, :piece_label,        :string
    add_column :grocery_items, :piece_label_plural, :string
  end
end
