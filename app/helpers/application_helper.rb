module ApplicationHelper
  include Pagy::Frontend

  # Retourne un Greeting(text:, subtext:) personnalisé et aléatoire.
  # Délègue la logique au GreetingService pour une meilleure séparation des responsabilités.
  # La paire est stockée en session pour rester cohérente pendant toute la journée.
  # Une nouvelle paire est générée chaque jour pour garder le charme de la personnalisation.
  def random_greeting(user)
    today = Date.today.to_s
    data = session[:user_greeting]

    # Réinitialiser si nouveau jour ou si le format en session est invalide (ex: ancienne session)
    if session[:greeting_date] != today || !data.is_a?(Hash)
      session[:greeting_date] = today
      greeting = GreetingService.new(user).random_greeting
      # Stocker avec clés string : JSON (cookie store) dépersiste les symboles en strings
      session[:user_greeting] = { "text" => greeting.text, "subtext" => greeting.subtext }
      data = session[:user_greeting]
    end

    GreetingService::Greeting.new(data["text"], data["subtext"])
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

  # Icônes Feather inline (petits SVG courants sans fichier séparé)
  # Usage : = svg_icon(:edit, size: 13)
  #         = svg_icon(:heart, size: 14, fill: "currentColor")
  FEATHER_ICONS = {
    "chevron-left"  => '<polyline points="15 18 9 12 15 6"/>',
    "chevron-down"  => '<polyline points="6 9 12 15 18 9"/>',
    "plus"          => '<line x1="12" y1="5" x2="12" y2="19"/><line x1="5" y1="12" x2="19" y2="12"/>',
    "list"          => '<line x1="8" y1="6" x2="21" y2="6"/><line x1="8" y1="12" x2="21" y2="12"/><line x1="8" y1="18" x2="21" y2="18"/><line x1="3" y1="6" x2="3.01" y2="6"/><line x1="3" y1="12" x2="3.01" y2="12"/><line x1="3" y1="18" x2="3.01" y2="18"/>',
    "upload"        => '<path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4"/><polyline points="17 8 12 3 7 8"/><line x1="12" y1="3" x2="12" y2="15"/>',
    "share"         => '<circle cx="18" cy="5" r="3"/><circle cx="6" cy="12" r="3"/><circle cx="18" cy="19" r="3"/><line x1="8.59" y1="13.51" x2="15.42" y2="17.49"/><line x1="15.41" y1="6.51" x2="8.59" y2="10.49"/>',
    "edit"          => '<path d="M11 4H4a2 2 0 0 0-2 2v14a2 2 0 0 0 2 2h14a2 2 0 0 0 2-2v-7"/><path d="M18.5 2.5a2.121 2.121 0 0 1 3 3L12 15l-4 1 1-4 9.5-9.5z"/>',
    "trash"         => '<polyline points="3 6 5 6 21 6"/><path d="M19 6v14a2 2 0 0 1-2 2H7a2 2 0 0 1-2-2V6m3 0V4a2 2 0 0 1 2-2h4a2 2 0 0 1 2 2v2"/>',
    "heart"         => '<path d="M20.84 4.61a5.5 5.5 0 0 0-7.78 0L12 5.67l-1.06-1.06a5.5 5.5 0 0 0-7.78 7.78l1.06 1.06L12 21.23l7.78-7.78 1.06-1.06a5.5 5.5 0 0 0 0-7.78z"/>',
    "sparkle"       => '<path d="M12 2v4M12 18v4M4.93 4.93l2.83 2.83M16.24 16.24l2.83 2.83M2 12h4M18 12h4M4.93 19.07l2.83-2.83M16.24 7.76l2.83-2.83"/>',
    "shuffle"       => '<polyline points="16 3 21 3 21 8"/><line x1="4" y1="20" x2="21" y2="3"/><polyline points="21 16 21 21 16 21"/><line x1="15" y1="15" x2="21" y2="21"/>',
    "search"        => '<circle cx="11" cy="11" r="8"/><line x1="21" y1="21" x2="16.65" y2="16.65"/>',
    "arrow-right"   => '<line x1="5" y1="12" x2="19" y2="12"/><polyline points="12 5 19 12 12 19"/>',
    "grip-vertical" => '<circle cx="9" cy="5" r="1" fill="currentColor"/><circle cx="9" cy="12" r="1" fill="currentColor"/><circle cx="9" cy="19" r="1" fill="currentColor"/><circle cx="15" cy="5" r="1" fill="currentColor"/><circle cx="15" cy="12" r="1" fill="currentColor"/><circle cx="15" cy="19" r="1" fill="currentColor"/>',
    "book-open"     => '<path d="M2 3h6a4 4 0 0 1 4 4v14a3 3 0 0 0-3-3H2z"/><path d="M22 3h-6a4 4 0 0 0-4 4v14a3 3 0 0 1 3-3h7z"/>'
  }.freeze

  def svg_icon(name, size: nil, css_class: nil, fill: "none")
    body = FEATHER_ICONS[name.to_s] || ""
    attrs = %w[xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"]
    attrs << %(width="#{size}" height="#{size}") if size
    attrs << %(class="#{ERB::Util.html_escape(css_class)}") if css_class
    attrs << %(fill="#{ERB::Util.html_escape(fill)}")
    "<svg #{attrs.join(' ')}>#{body}</svg>".html_safe
  end

  private

  # Nettoie le message d'erreur pour ne garder que l'essentiel
  def clean_error_message(message)
    message
  end
end
