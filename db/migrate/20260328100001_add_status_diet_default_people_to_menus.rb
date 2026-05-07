# frozen_string_literal: true

# Ajoute les colonnes nécessaires à l'architecture "draft persisté" (UC1/UC2)
#
# - status       : enum draft=0 / active=1. Un brouillon EST un menu, juste non finalisé.
# - diet         : régime alimentaire du menu (aligné avec Recipe.diet enum)
# - default_people : nombre de personnes par défaut pour tous les repas du menu
class AddStatusDietDefaultPeopleToMenus < ActiveRecord::Migration[7.2]
  def change
    # Statut du menu : draft (en cours de composition) ou active (finalisé)
    add_column :menus, :status, :integer, default: 0, null: false

    # Régime alimentaire (omnivore=0, vegetarien=1, vegan=2, pescetarien=3)
    # Nullable : les menus existants avant cette migration n'ont pas de régime
    add_column :menus, :diet, :integer

    # Nombre de personnes par défaut pour les repas du menu
    # Initialisé à 2 (valeur par défaut raisonnable)
    add_column :menus, :default_people, :integer, default: 2, null: false

    # Index pour requêtes fréquentes : "mes drafts", "mes menus actifs"
    add_index :menus, :status
    add_index :menus, [:user_id, :status]
  end
end
