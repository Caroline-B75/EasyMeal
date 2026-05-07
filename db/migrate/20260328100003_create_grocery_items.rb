# frozen_string_literal: true

# Crée la table des lignes de liste de courses (UC3)
#
# Une GroceryItem représente une ligne de la liste de courses d'un menu.
# Elle peut être générée automatiquement (source: :generated) à partir des recettes
# ou ajoutée manuellement par l'utilisateur (source: :manual).
#
# Règle de régénération :
# - Les items :generated sont recalculés à chaque activation/modification du menu
# - Les items :manual ne sont JAMAIS supprimés lors d'une régénération
class CreateGroceryItems < ActiveRecord::Migration[7.2]
  def change
    create_table :grocery_items do |t|
      # Menu auquel appartient cette ligne
      t.references :menu, null: false, foreign_key: true

      # Ingrédient lié (null si ligne custom sans ingrédient en base)
      t.references :ingredient, null: true, foreign_key: true

      # Nom affiché (copié depuis ingredient.name à la création, ou saisi manuellement)
      # Stocké explicitement pour éviter le N+1 et pour les items custom sans ingredient_id
      t.string :name, null: false

      # Quantité en unité de base de l'ingrédient (g, ml, piece, cac)
      # Toujours stockée en base pour faciliter l'agrégation et les calculs
      t.decimal :quantity_base, precision: 10, scale: 3, null: false

      # Groupe d'unités : mass=0, volume=1, count=2, spoon=3
      # Dupliqué depuis ingredient pour éviter la jointure à l'affichage
      t.integer :unit_group, null: false

      # Unité de base (g, ml, piece, cac) — dupliqué depuis ingredient
      t.string :base_unit, null: false

      # Catégorie / rayon (dupliqué depuis ingredient pour le groupement par rayon)
      # Permet de grouper les items sans jointure sur ingredients
      t.integer :category

      # Statut "acheté"
      t.boolean :checked, default: false, null: false

      # Source : generated=0 (calculé depuis les recettes) | manual=1 (ajouté par l'utilisateur)
      t.integer :source, default: 0, null: false

      # Ordre d'affichage au sein du rayon
      t.integer :position

      t.timestamps
    end

    # Récupération de tous les items d'un menu (requête principale)
    add_index :grocery_items, [:menu_id, :source]

    # Recherche rapide d'un item par ingrédient dans un menu (détection doublons, agrégation)
    add_index :grocery_items, [:menu_id, :ingredient_id]

    # Groupement par rayon
    add_index :grocery_items, [:menu_id, :category]
  end
end
