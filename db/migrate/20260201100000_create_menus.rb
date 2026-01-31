# frozen_string_literal: true

# Crée la table des menus
# Un menu représente une planification de repas sur une période
# Chaque utilisateur peut avoir plusieurs menus (semaine, événement, etc.)
class CreateMenus < ActiveRecord::Migration[7.2]
  def change
    create_table :menus do |t|
      # Nom du menu (ex: "Menu semaine 5", "Anniversaire Marie")
      t.string :name, null: false

      # Utilisateur propriétaire du menu
      t.references :user, null: false, foreign_key: true

      # Date de début du menu (optionnel, pour planification calendaire)
      t.date :start_date

      t.timestamps
    end

    # Index pour récupérer rapidement les menus d'un utilisateur
    add_index :menus, [:user_id, :start_date]
  end
end
