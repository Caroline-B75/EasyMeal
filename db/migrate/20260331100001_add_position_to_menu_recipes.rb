# frozen_string_literal: true

class AddPositionToMenuRecipes < ActiveRecord::Migration[7.1]
  def change
    add_column :menu_recipes, :position, :integer, default: 0, null: false
    add_index :menu_recipes, [:menu_id, :position]
  end
end
