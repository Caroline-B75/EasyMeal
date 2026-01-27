class ApplicationController < ActionController::Base
  include Pundit

  # Configurer les paramètres autorisés pour Devise
  before_action :configure_permitted_parameters, if: :devise_controller?

  # Gérer les erreurs d'autorisation
  rescue_from Pundit::NotAuthorizedError, with: :user_not_authorized

  private

  def user_not_authorized
    flash[:alert] = "Vous n'êtes pas autorisé à effectuer cette action."
    redirect_to(request.referrer || root_path)
  end

  # Autoriser les paramètres supplémentaires pour Devise
  def configure_permitted_parameters
    devise_parameter_sanitizer.permit(:sign_up, keys: [:username, :first_name, :last_name])
    devise_parameter_sanitizer.permit(:account_update, keys: [:username, :first_name, :last_name])
  end
end