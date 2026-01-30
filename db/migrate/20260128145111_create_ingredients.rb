class CreateIngredients < ActiveRecord::Migration[7.2]
  def change
    create_table :ingredients do |t|
      t.string :name, null: false
      t.integer :category, null: false
      t.integer :unit_group, null: false
      t.string :base_unit, null: false
      t.integer :season_months, array: true, default: []
      t.jsonb :aliases, default: {}

      t.timestamps
    end

    add_index :ingredients, :name, unique: true
    add_index :ingredients, :category
    add_index :ingredients, :aliases, using: :gin
  end
end