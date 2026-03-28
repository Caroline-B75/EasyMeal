class CreateRecipes < ActiveRecord::Migration[7.2]
  def change
    create_table :recipes do |t|
      t.string :name, null: false
      t.text :description
      t.text :instructions
      t.integer :default_servings, null: false
      t.integer :prep_time_minutes
      t.integer :cook_time_minutes
      t.integer :difficulty
      t.integer :price
      t.integer :diet, null: false
      t.string :appliance
      t.string :source_url

      t.timestamps
    end

    add_index :recipes, :name
    add_index :recipes, :diet
    add_index :recipes, :difficulty
  end
end