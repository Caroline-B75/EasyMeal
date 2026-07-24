# frozen_string_literal: true

class AddMealCountAndConfiguredFlagToUsers < ActiveRecord::Migration[7.2]
  def change
    # Nombre de repas par défaut pour la génération de menu
    add_column :users, :default_number_of_meals, :integer, default: 7, null: false

    # Indique si l'utilisateur a explicitement configuré ses préférences (onboarding)
    # false par défaut → le formulaire de génération est affiché avec option de mémorisation
    # true après premier enregistrement → le bouton "Créer un menu" génère directement
    add_column :users, :preferences_configured, :boolean, default: false, null: false
  end
end
