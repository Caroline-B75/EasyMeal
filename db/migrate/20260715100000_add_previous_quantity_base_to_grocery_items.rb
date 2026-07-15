# frozen_string_literal: true

# Mémorise l'ancienne quantité d'un article de courses quand une réconciliation
# (Groceries::BuildForMenuService) augmente la quantité d'un item qui était coché.
# Sert à afficher le badge « Était X — déjà acheté ? » sur la liste de courses.
# Mêmes précision/échelle que quantity_base (decimal 10,3).
class AddPreviousQuantityBaseToGroceryItems < ActiveRecord::Migration[7.2]
  def change
    add_column :grocery_items, :previous_quantity_base, :decimal, precision: 10, scale: 3, null: true
  end
end
