# Helper pour les menus — labels d'affichage et badges
module MenusHelper
  DIET_LABELS = {
    "omnivore"    => "Omnivore",
    "vegetarien"  => "Végétarien",
    "vegan"       => "Vegan",
    "pescetarien" => "Pescétarien"
  }.freeze

  # Retourne le label français du régime alimentaire
  def menu_diet_label(diet)
    DIET_LABELS.fetch(diet.to_s, diet.to_s.humanize)
  end

  # Retourne le label du statut du menu
  def menu_status_label(menu)
    menu.status_draft? ? "Brouillon" : "Actif"
  end

  # Classe CSS du badge de statut
  def menu_status_badge_class(menu)
    menu.status_draft? ? "badge badge-draft" : "badge badge-active"
  end
end
