# frozen_string_literal: true

# Gestion des préférences du profil utilisateur.
# Permet de configurer les paramètres par défaut pour la génération de menus
# (régime alimentaire, nombre de personnes, nombre de repas).
#
# Ces préférences sont mémorisées sur le User et pré-remplissent (ou bypassent)
# le formulaire de création de menu selon que l'utilisateur est configuré ou non.
class ProfilesController < ApplicationController
  before_action :authenticate_user!

  # GET /profile/preferences
  def preferences
    @user = current_user
  end

  # PATCH /profile/preferences
  def update_preferences
    @user = current_user
    if @user.update(preferences_params)
      redirect_to preferences_profile_path,
                  notice: "Préférences enregistrées.",
                  status: :see_other
    else
      render :preferences, status: :unprocessable_entity
    end
  end

  private

  # preferences_configured passe automatiquement à true dès le premier enregistrement.
  def preferences_params
    params.require(:user)
          .permit(:default_diet, :default_people, :default_number_of_meals)
          .merge(preferences_configured: true)
  end
end
