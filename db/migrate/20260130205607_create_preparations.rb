class CreatePreparations < ActiveRecord::Migration[7.2]
  def change
    create_table :preparations do |t|
      t.references :recipe, null: false, foreign_key: true
      t.references :ingredient, null: false, foreign_key: true
      t.decimal :quantity_base, precision: 10, scale: 3, null: false

      t.timestamps
    end

    # Index pour éviter les doublons (une recette ne peut pas avoir 2x le même ingrédient)
    add_index :preparations, [:recipe_id, :ingredient_id], unique: true
  end
end