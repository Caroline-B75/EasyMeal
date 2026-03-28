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
    menu.status_draft? ? "Brouillon" : "Actif"
  end

  # Classe CSS du badge de statut
  def menu_status_badge_class(menu)
    menu.status_draft? ? "badge badge-draft" : "badge badge-active"
  end
end
