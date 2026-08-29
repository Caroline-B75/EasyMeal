class AddImportFieldsToRecipes < ActiveRecord::Migration[7.2]
  def change
    add_column :recipes, :status, :integer, default: 1, null: false
    add_column :recipes, :source_type, :string
    add_column :recipes, :ai_raw_data, :jsonb

    add_index :recipes, :status
  end
end
