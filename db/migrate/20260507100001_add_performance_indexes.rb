class AddPerformanceIndexes < ActiveRecord::Migration[7.2]
  def up
    add_index :ingredients, :season_months, using: :gin,
              name: "index_ingredients_on_season_months"

    execute <<~SQL
      CREATE INDEX index_recipes_on_total_time
        ON recipes ((COALESCE(prep_time_minutes, 0) + COALESCE(cook_time_minutes, 0)));
    SQL
  end

  def down
    remove_index :ingredients, name: "index_ingredients_on_season_months"
    execute "DROP INDEX IF EXISTS index_recipes_on_total_time;"
  end
end
