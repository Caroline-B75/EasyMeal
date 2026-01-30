class ApplicationController < ActionController::Base
  include Pundit::Authorization
  include Pagy::Backend

  # Configurer les paramètres autorisés pour Devise
  before_action :configure_permitted_parameters, if: :devise_controller?
  
  # Réinitialiser la phrase d'accueil à chaque connexion
  after_action :reset_greeting_on_sign_in, if: :user_signed_in?

  # Gérer les erreurs d'autorisation
  rescue_from Pundit::NotAuthorizedError, with: :user_not_authorized

  private

  def user_not_authorized
    flash[:alert] = "Tu n'es pas autorisé(e) à effectuer cette action."
    redirect_to(request.referrer || root_path)
  end

  # Autoriser les paramètres supplémentaires pour Devise
  def configure_permitted_parameters
    devise_parameter_sanitizer.permit(:sign_up, keys: [:username, :first_name, :last_name, :gender])
    devise_parameter_sanitizer.permit(:account_update, keys: [:username, :first_name, :last_name, :gender])
  end
  
  # Réinitialise la phrase d'accueil si c'est une nouvelle session
  def reset_greeting_on_sign_in
    if controller_name == 'sessions' && action_name == 'create'
      session.delete(:user_greeting)
    end
  end
end