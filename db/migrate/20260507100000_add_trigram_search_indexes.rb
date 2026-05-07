class AddTrigramSearchIndexes < ActiveRecord::Migration[7.2]
  def up
    enable_extension "pg_trgm"

    add_index :recipes, :name, using: :gin, opclass: :gin_trgm_ops,
              name: "index_recipes_on_name_trgm"
    add_index :tags, :name, using: :gin, opclass: :gin_trgm_ops,
              name: "index_tags_on_name_trgm"
    add_index :ingredients, :name, using: :gin, opclass: :gin_trgm_ops,
              name: "index_ingredients_on_name_trgm"
  end

  def down
    remove_index :recipes, name: "index_recipes_on_name_trgm"
    remove_index :tags, name: "index_tags_on_name_trgm"
    remove_index :ingredients, name: "index_ingredients_on_name_trgm"
    disable_extension "pg_trgm"
  end
end
