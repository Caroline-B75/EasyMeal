# frozen_string_literal: true

# « Je m'en occupe » : le membre du foyer qui achète un article de la liste de
# courses. Vide tant que personne ne l'a pris ; cocher l'article le donne à qui
# le coche.
class AddClaimedByToGroceryItems < ActiveRecord::Migration[8.1]
  def change
    add_reference :grocery_items, :claimed_by, foreign_key: { to_table: :users }
  end
end
