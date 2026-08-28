# frozen_string_literal: true

# Le carnet de commandes de l'import IA : une ligne par tentative, du dépôt de
# la source jusqu'au brouillon obtenu.
#
# Avant, l'extraction se jouait entièrement dans la requête HTTP : rien n'était
# écrit tant que l'IA n'avait pas répondu, et un fil coupé — les routeurs
# d'hébergeurs abandonnent une requête vers 30 s, l'extraction en demande jusqu'à
# 60 — emportait le travail. Désormais la commande est enregistrée d'abord, un
# job la traite ensuite, et la page d'attente lit son état ici. Un redémarrage du
# serveur en cours de route ne perd donc plus rien.
class CreateRecipeImports < ActiveRecord::Migration[7.2]
  def change
    create_table :recipe_imports do |t|
      t.references :user, null: false, foreign_key: true

      # Le brouillon produit — nul jusqu'à la réussite de l'extraction.
      t.references :recipe, foreign_key: true

      t.integer :status,      null: false, default: 0
      t.string  :source_type, null: false
      t.string  :source_url

      # Motif d'échec relayé tel quel à l'utilisatrice : elle doit savoir si
      # c'est l'URL, la photo ou l'IA qui a posé problème.
      t.text :error_message

      t.timestamps
    end
  end
end
