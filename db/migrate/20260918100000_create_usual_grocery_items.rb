# frozen_string_literal: true

# Les courses habituelles d'un foyer : ce qu'il achète chaque semaine ou presque,
# ajouté d'un bouton à la liste de courses (cf. UsualGroceryItem).
#
# On garde ce qui a été saisi — « 6 L » reste 6 et « l » — et non une quantité
# de base : la conversion se fait à l'ajout, par le même chemin que le
# formulaire « Ajouter un article ».
class CreateUsualGroceryItems < ActiveRecord::Migration[8.1]
  def change
    create_table :usual_grocery_items do |t|
      t.references :household, null: false, foreign_key: true
      # Facultatif : un article hors catalogue (dentifrice, éponges) se décrit seul
      t.references :ingredient, foreign_key: true
      t.string :name, null: false
      t.decimal :quantity, precision: 10, scale: 3, null: false
      t.string :unit, null: false
      t.integer :category
      t.timestamps
    end
  end
end
