module ApplicationHelper
  include Pagy::Frontend

  # Retourne un message d'accueil personnalisé et aléatoire
  # Délègue la logique au GreetingService pour une meilleure séparation des responsabilités
  # La phrase est stockée en session pour rester cohérente pendant toute la journée
  # Une nouvelle phrase est générée chaque jour pour garder le charme de la personnalisation
  def random_greeting(user)
    today = Date.today.to_s

    # Réinitialiser la phrase si on est un nouveau jour
    if session[:greeting_date] != today
      session[:greeting_date] = today
      session[:user_greeting] = GreetingService.new(user).random_greeting
    end

    session[:user_greeting]
  end

  # Vérifie si on est sur la page d'accueil
  def home_page?
    controller_name == "home" && action_name == "index"
  end

  # ============================================
  # SYSTÈME DE GESTION D'ERREURS INLINE
  # ============================================

  # Affiche les erreurs d'un champ directement sous celui-ci
  # Usage: = field_errors(@recipe, :name)
  # ou pour les nested attributes: = field_errors(f.object, :quantity_base)
  def field_errors(object, attribute)
    return unless object.errors[attribute].any?

    # Messages d'erreur courts et clairs (sans le nom du champ)
    messages = object.errors[attribute].map { |msg| clean_error_message(msg) }

    content_tag(:div, class: "field-errors", data: { field_error: true }) do
      messages.map { |msg| content_tag(:span, msg, class: "field-error") }.join.html_safe
    end
  end

  # Vérifie si un champ a des erreurs (pour ajouter une classe CSS)
  def field_has_errors?(object, attribute)
    object.errors[attribute].any?
  end

  # Retourne la classe CSS d'erreur si le champ a des erreurs
  def field_error_class(object, attribute)
    field_has_errors?(object, attribute) ? "has-error" : ""
  end

  private

  # Nettoie le message d'erreur pour ne garder que l'essentiel
  def clean_error_message(message)
    message
  end
end
