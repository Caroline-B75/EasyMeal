# Helper pour les menus — labels d'affichage et badges
module MenusHelper
  DIET_LABELS = {
    "omnivore"    => "Omnivore",
    "vegetarien"  => "Végétarien",
    "vegan"       => "Vegan",
    "pescetarien" => "Pescétarien"
  }.freeze

  DIET_DESCRIPTIONS = {
    "omnivore"    => "Toutes les recettes disponibles",
    "vegetarien"  => "Sans viande ni poisson",
    "vegan"       => "Sans produits d'origine animale",
    "pescetarien" => "Végétarien + poisson"
  }.freeze

  # Retourne le label français du régime alimentaire
  def menu_diet_label(diet)
    DIET_LABELS.fetch(diet.to_s, diet.to_s.humanize)
  end

  # Retourne la description du régime alimentaire
  def menu_diet_description(diet)
    DIET_DESCRIPTIONS.fetch(diet.to_s, "")
  end

  FRENCH_MONTHS = %w[
    janvier février mars avril mai juin
    juillet août septembre octobre novembre décembre
  ].freeze

  # Retourne une date formatée en français (ex: "28 mars 2026")
  def french_date(date)
    "#{date.day} #{FRENCH_MONTHS[date.month - 1]} #{date.year}"
  end

  # Retourne le label du statut du menu
  def menu_status_label(menu)
    case
    when menu.status_draft?    then menu_draft_status_label(menu)
    when menu.status_active?   then "Actif"
    when menu.status_archived? then "Archivé"
    else menu.status.to_s.humanize
    end
  end

  # Classe CSS du badge de statut
  def menu_status_badge_class(menu)
    case
    when menu.status_draft?    then "badge badge-draft"
    when menu.status_active?   then "badge badge-active"
    when menu.status_archived? then "badge badge-archived"
    else "badge"
    end
  end

  def menu_draft_status_label(menu)
    menu.pending_revalidation? ? "À revalider" : "À valider"
  end

  def menu_draft_section_label(menu)
    menu.pending_revalidation? ? "Modification à revalider" : "Menu à valider"
  end

  def menu_validation_button_label(menu)
    menu.pending_revalidation? ? "Revalider les modifications" : "Valider et générer la liste de courses"
  end

  # Construit le message de confirmation de validation d'un menu (R3.2bis).
  # Honnête sur les conséquences : génération de liste, réconciliation d'une liste
  # existante (REvalidation), et archivage de l'éventuel menu actif courant.
  # @param menu [Menu] le brouillon en cours de validation
  # @return [String] message destiné au turbo_confirm
  def menu_validation_confirm(menu)
    parts = if menu.pending_revalidation?
      [ "Revalider ces modifications ? Ta liste de courses sera mise à jour." ]
    else
      [ "Valider ce menu ? La liste de courses sera générée." ]
    end

    if menu.grocery_items.exists?
      parts << "Ta liste existante sera mise à jour en conservant tes articles cochés (sauf quantités augmentées)."
    end

    if menu.user.menus.active_menus.where.not(id: menu.id).exists?
      parts << "Ton menu actif actuel sera archivé."
    end

    parts.join(" ")
  end

  # Options pour le select du nombre de personnes (mockup card grid)
  PEOPLE_OPTIONS = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 12].freeze

  def people_select_options
    PEOPLE_OPTIONS.map { |n| ["#{n} pers.", n] }
  end
end
