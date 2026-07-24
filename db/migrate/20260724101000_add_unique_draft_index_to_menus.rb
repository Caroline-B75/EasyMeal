# frozen_string_literal: true

class AddUniqueDraftIndexToMenus < ActiveRecord::Migration[7.2]
  def up
    duplicate_draft_ids = select_values(<<~SQL.squish).map(&:to_i)
      SELECT id FROM (
        SELECT id,
               ROW_NUMBER() OVER (PARTITION BY user_id ORDER BY updated_at DESC, id DESC) AS draft_rank
        FROM menus
        WHERE status = 0
      ) ranked_drafts
      WHERE draft_rank > 1
    SQL

    if duplicate_draft_ids.any?
      ids = duplicate_draft_ids.join(",")
      execute "DELETE FROM grocery_items WHERE menu_id IN (#{ids})"
      execute "DELETE FROM menu_recipes WHERE menu_id IN (#{ids})"
      execute "DELETE FROM menus WHERE id IN (#{ids})"
    end

    add_index :menus, :user_id,
              unique: true,
              where: "status = 0",
              name: "index_menus_on_user_id_unique_draft"
  end

  def down
    remove_index :menus, name: "index_menus_on_user_id_unique_draft"
  end
end