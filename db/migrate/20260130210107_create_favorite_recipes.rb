class CreateFavoriteRecipes < ActiveRecord::Migration[7.2]
  def change
    create_table :favorite_recipes do |t|
      t.references :user, null: false, foreign_key: true
      t.references :recipe, null: false, foreign_key: true

      t.timestamps
    end

    # Un utilisateur ne peut mettre en favori qu'une seule fois la même recette
    add_index :favorite_recipes, [:user_id, :recipe_id], unique: true
  end
end