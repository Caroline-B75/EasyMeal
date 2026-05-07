# frozen_string_literal: true

# Ajoute le statut :archived (2) à l'enum status des menus.
# Cycle de vie complet : draft → active → archived.
# Un seul menu peut être actif par utilisateur à un instant donné.
class AddArchivedStatusToMenus < ActiveRecord::Migration[7.2]
  def up
    # L'enum integer accepte déjà la valeur 2, pas de changement de colonne nécessaire.
    # On ajoute un index partiel pour garantir au plus UN menu actif par user.
    add_index :menus, :user_id,
              unique: true,
              where: "status = 1",
              name: "index_menus_on_user_id_unique_active"
  end

  def down
    remove_index :menus, name: "index_menus_on_user_id_unique_active"
  end
end
