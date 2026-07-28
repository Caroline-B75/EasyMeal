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

  # Libellé du bandeau de statut en haut de la page d'un menu.
  # Registre différent de menu_status_label (badges compacts des listes) : ce
  # bandeau annonce l'état de la page que l'utilisatrice est en train de lire.
  def menu_head_kicker_label(menu)
    case
    when menu.status_draft?  then menu.pending_revalidation? ? "Modification à revalider" : "Menu en préparation"
    when menu.status_active? then "Menu actif"
    else "Menu archivé"
    end
  end

  # Détails de la ligne méta de l'en-tête, affichés après le nombre de repas.
  # Régime et personnes ne sont listés que hors brouillon : le brouillon les
  # expose juste en dessous sous forme de réglages modifiables.
  def menu_head_meta_details(menu)
    details = []
    unless menu.status_draft?
      details << menu_diet_label(menu.diet)
      details << "#{menu.default_people} pers. par défaut"
    end
    details << "Créé le #{french_date(menu.created_at)}"
    details
  end

  # Formule commune décrivant la réconciliation de la liste de courses existante
  # (articles cochés conservés, sauf si leur quantité augmente) — partagée entre
  # la confirmation de retour en brouillon et celle de revalidation.
  GROCERY_RECONCILE_NOTICE = "sera mise à jour : les articles déjà cochés le restent, " \
                              "sauf si leur quantité augmente.".freeze

  # Confirmation du retour en brouillon d'un menu actif (R3.2bis).
  # Un seul brouillon peut exister : si l'utilisatrice en a déjà un, cette
  # modification le remplacera — on l'annonce avant d'agir.
  def menu_revert_to_draft_confirm(menu)
    message = "Repasser ce menu en brouillon pour le modifier ? À la revalidation, ta liste de courses " \
              "#{GROCERY_RECONCILE_NOTICE}"
    existing_draft = current_user.menus.status_draft.where.not(id: menu.id).recent.first
    return message if existing_draft.nil?

    "#{message}\n\nAttention : tu as déjà un menu « #{existing_draft.name} » à valider. " \
      "Il sera remplacé par cette modification à revalider."
  end

  def menu_validation_button_label(menu)
    menu.pending_revalidation? ? "Revalider les modifications" : "Valider et générer la liste de courses"
  end

  # Construit le message de confirmation de validation d'un menu (R3.2bis).
  # Honnête sur les conséquences : génération de liste, réconciliation d'une liste
  # existante (revalidation), et archivage de l'éventuel menu actif courant.
  # @param menu [Menu] le brouillon en cours de validation
  # @return [String] message destiné au turbo_confirm
  def menu_validation_confirm(menu)
    parts = if menu.pending_revalidation?
      [ "Revalider ces modifications ? Ta liste de courses #{GROCERY_RECONCILE_NOTICE}" ]
    else
      [ "Valider ce menu ? La liste de courses sera générée." ]
    end

    if menu.user.menus.active_menus.where.not(id: menu.id).exists?
      parts << "Ton menu actif actuel sera archivé."
    end

    parts.join(" ")
  end

  # Options pour le select du nombre de personnes (mockup card grid)
  PEOPLE_OPTIONS = (1..20).to_a.freeze

  def people_select_options
    PEOPLE_OPTIONS.map { |n| ["#{n} pers.", n] }
  end
end
