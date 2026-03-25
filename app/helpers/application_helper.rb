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
      safe_join(messages.map { |msg| content_tag(:span, msg, class: "field-error") })
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

  # ============================================
  # SYSTÈME D'ICÔNES SVG INLINE
  # ============================================
  #
  # Insère un fichier SVG inline pour permettre la stylisation via variables CSS.
  # Les SVGs doivent utiliser fill="currentColor" (monocouleur) ou
  # fill="var(--icon-color-1)" / fill="var(--icon-color-2)" (bicouleur).
  #
  # Usage monocouleur :
  #   = inline_svg("cook-book", css_class: "icon-title", color: "var(--color-primary)")
  #
  # Usage bicouleur (le SVG doit avoir 2 groupes de paths avec --icon-color-1 et --icon-color-2) :
  #   = inline_svg("my-icon", css_class: "icon-md", color: "var(--color-primary)", color2: "var(--color-secondary)")
  #
  def inline_svg(icon_name, css_class: nil, color: nil, color2: nil, size: nil)
    file_path = Rails.root.join("app/assets/images/icones/#{icon_name}.svg")
    return "".html_safe unless File.exist?(file_path)

    svg_content = File.read(file_path)

    # Construction du style inline pour les variables de couleur CSS
    style_parts = []
    style_parts << "color: #{color}" if color.present?
    style_parts << "--icon-color-2: #{color2}" if color2.present?
    style_parts << "width: #{size}; height: #{size}" if size.present?

    # Construction des attributs à injecter dans la balise <svg>
    css_classes = ["svg-icon", css_class].compact.join(" ")
    extra_attrs = " class=\"#{css_classes}\""
    extra_attrs += " style=\"#{style_parts.join('; ')}\"" if style_parts.any?
    extra_attrs += " aria-hidden=\"true\""

    svg_content = svg_content.gsub(/<svg\b/, "<svg#{extra_attrs}")
    svg_content.html_safe
  end

  private

  # Nettoie le message d'erreur pour ne garder que l'essentiel
  def clean_error_message(message)
    message
  end
end
