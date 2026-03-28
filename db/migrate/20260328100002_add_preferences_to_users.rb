# frozen_string_literal: true

# Ajoute les préférences utilisateur nécessaires pour la génération de menu (UC1/UC6)
#
# - default_diet    : régime alimentaire par défaut de l'utilisateur
#                     Pré-remplit le formulaire de génération de menu
# - default_people  : nombre de personnes par défaut
#                     Pré-remplit le formulaire de génération de menu
class AddPreferencesToUsers < ActiveRecord::Migration[7.2]
  def change
    # Régime par défaut (omnivore=0, vegetarien=1, vegan=2, pescetarien=3)
    # Défaut omnivore pour les utilisateurs existants
    add_column :users, :default_diet, :integer, default: 0, null: false

    # Nombre de personnes par défaut (minimum 1)
    # Défaut 2 personnes
    add_column :users, :default_people, :integer, default: 2, null: false
  end
end
