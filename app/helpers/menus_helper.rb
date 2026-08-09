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
    PEOPLE_OPTIONS.map { |n| [ "#{n} pers.", n ] }
  end

  # === Répartition des repas par moment (UC7) ===

  # Résumé d'une semaine encore vide — le formulaire s'ouvre là-dessus.
  NO_MEALS_SUMMARY = "Aucun repas".freeze

  # Résumé lisible d'une répartition — « 7 petits-déjs · 2 déjs · 1 apéro ».
  # Seuls les moments commandés apparaissent (cahier des charges UC7, ch. 2).
  # Le contrôleur Stimulus meal-counts reconstruit cette même chaîne à chaque
  # clic, à partir des libellés que le partial des steppers lui transmet : le
  # français n'est écrit qu'une fois, dans les locales.
  # @param meal_counts [MealCounts]
  # @return [String]
  def meal_counts_summary(meal_counts)
    parts = MealTypes::MEAL_TYPES.filter_map do |meal_type|
      count = meal_counts[meal_type]
      "#{count} #{MealTypes.short_label(meal_type, count)}" if count.positive?
    end

    parts.join(" · ").presence || NO_MEALS_SUMMARY
  end

  # Répartition pré-remplie dans le formulaire de paramètres : la commande
  # mémorisée du menu d'abord (re-génération à l'identique — elle retient la
  # demande même quand des pools trop maigres ont donné moins de repas), sinon
  # ce que le menu contient (brouillon d'avant les quotas), sinon la semaine
  # type mémorisée par l'utilisatrice — sinon rien : tous les steppers à zéro.
  # @param menu [Menu] menu neuf ou brouillon existant
  # @param user [User]
  # @return [MealCounts]
  def form_meal_counts(menu, user)
    requested = menu.requested_counts
    return requested if requested.any?

    composed = MealCounts.from_menu_recipes(menu.menu_recipes)
    composed.any? ? composed : user.preferred_meal_counts
  end

  # === Manques du brouillon (UC7, chapitre 3) ===

  # Résumé compact des manques face à la commande — « Il manque 6 petits-déjeuners,
  # 2 déjeuners pour compléter ce menu. » Une seule ligne pour tout le menu, en
  # tête de la grille : celle-ci n'affiche aucun moment, il n'existe nulle part
  # ailleurs où poser l'information. Ce n'est jamais une erreur, seulement un état.
  # @param missing_counts [Hash{String => Integer}] Menu#missing_meal_counts
  # @return [String, nil] nil quand la commande est honorée : rien à afficher
  def missing_meals_message(missing_counts)
    return nil if missing_counts.empty?

    meals = missing_counts.map { |meal_type, count| "#{count} #{MealTypes.inline_label(meal_type, count)}" }
    t("menus.draft.missing_meals", meals: meals.join(", "))
  end

  # === Carte de repas enrichie (UC7, chapitre 4) ===

  # Enveloppe une section de carte de repas (photo, nom) d'un lien vers la
  # recette : vérifier ingrédients et préparation sert autant en composant le
  # brouillon qu'en cuisinant depuis le menu actif. turbo_frame "_top" sort de
  # la turbo-frame de la carte (sinon la recette se chargerait dedans) ;
  # draggable "false" rend le glissement à la carte, qui l'utilise pour
  # réordonner la grille — le lien ne gêne donc jamais le drag & drop.
  # @param menu_recipe [MenuRecipe]
  # @param css_class [String] classe du bloc, identique quel que soit le statut
  def menu_card_recipe_link(menu_recipe, css_class, &block)
    link_to recipe_path(menu_recipe.recipe), class: css_class, draggable: "false",
            data: { turbo_frame: "_top", turbo_prefetch: "false" }, &block
  end

  # Options du sélecteur « Moment » d'une carte : vocabulaire partagé MealTypes,
  # dans l'ordre de la journée, en libellés compacts — le sélecteur ne dispose
  # que d'une demi-largeur de carte, qu'il partage avec celui du jour.
  # @return [Array<Array(String, String)>]
  def meal_type_select_options
    MealTypes::MEAL_TYPES.map { |type| [ MealTypes.compact_label(type), type ] }
  end

  # day_of_week suit Date#wday (0 = dimanche … 6 = samedi, cf. MenuRecipe) mais
  # le cahier des charges veut un sélecteur affiché Lundi → Dimanche : l'ordre
  # d'affichage diffère donc de l'ordre de stockage.
  DAY_OF_WEEK_DISPLAY_ORDER = [ 1, 2, 3, 4, 5, 6, 0 ].freeze

  # Options du sélecteur « Jour » d'une carte : "—" (vide, par défaut) puis
  # Lun…Dim. Aucune validation ni tri associés (cahier des charges) : le jour
  # annote la carte — et lui donne sa teinte — sans jamais la déplacer.
  # @return [Array<Array(String, String)>]
  def day_of_week_select_options
    blank = [ [ "—", "" ] ]
    blank + DAY_OF_WEEK_DISPLAY_ORDER.map { |wday| [ I18n.t("date.short_day_names")[wday], wday ] }
  end
end
