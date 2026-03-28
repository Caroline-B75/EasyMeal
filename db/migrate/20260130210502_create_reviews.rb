class CreateReviews < ActiveRecord::Migration[7.2]
  def change
    create_table :reviews do |t|
      t.references :user, null: false, foreign_key: true
      t.references :recipe, null: false, foreign_key: true
      t.integer :rating, null: false
      t.text :content

      t.timestamps
    end

    # Un utilisateur ne peut laisser qu'un seul avis par recette
    add_index :reviews, [:user_id, :recipe_id], unique: true
    add_index :reviews, :rating
  end
end