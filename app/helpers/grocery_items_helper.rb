# frozen_string_literal: true

# Liste de courses : identifiants des rayons et « Je m'en occupe » (répartition
# des articles entre les membres du foyer).
module GroceryItemsHelper
  # Identifiant DOM d'un rayon — cible des Turbo Streams qui le re-rendent.
  # @param category [String, nil] clé du rayon, nil pour « Divers »
  # @return [String] ex. "grocery_section_fruits_legumes"
  def grocery_section_id(category)
    "grocery_section_#{(category.presence || 'divers').parameterize}"
  end

  # Libellé d'un rayon. Les rayons de GroceryItem sont ceux d'Ingredient (enum
  # dupliqué, mêmes clés) : leurs libellés français n'existent qu'une fois.
  # @param category [String, nil]
  # @return [String] ex. « Fruits et légumes », « Divers »
  def grocery_section_name(category)
    category ? Ingredient.enum_label(:category, category) : "Divers"
  end

  # La liste se répartit-elle ? Seulement si le foyer du menu compte plusieurs
  # membres. Mémorisé pour la requête : chaque rayon et chaque ligne le demandent.
  # @param menu [Menu]
  def shared_grocery_list?(menu)
    @shared_grocery_lists ||= {}
    return @shared_grocery_lists[menu.household_id] if @shared_grocery_lists.key?(menu.household_id)

    @shared_grocery_lists[menu.household_id] = menu.household.shared?
  end

  # Le membre qui s'occupe de TOUT le rayon, s'il est seul à le faire : son
  # pseudo s'affiche alors une fois sur l'en-tête plutôt que sur chaque ligne.
  # @param items [Array<GroceryItem>]
  # @return [User, nil]
  def grocery_section_claimer(items)
    claimers = items.map(&:claimed_by).uniq
    claimers.first if claimers.size == 1
  end

  # Pastille « @pseudo » du membre qui s'occupe d'un article ou d'un rayon. La
  # sienne se distingue : on repère sa part d'un coup d'œil.
  # @param user [User]
  def grocery_claim_chip(user)
    mine = user == current_user
    tag.span("@#{user.username}",
             class: [ "grocery-claim-chip", ("grocery-claim-chip--mine" if mine) ],
             title: mine ? "Tu t'en occupes" : "@#{user.username} s'en occupe")
  end

  # Bouton de répartition d'une ligne (mode « Répartir ») : il dit l'état de
  # l'article et le change d'un geste. Ses tons sont ceux de la pastille de
  # pseudo : blanc quand l'article est libre, anthracite quand c'est le sien,
  # beige quand c'est celui d'un autre.
  #   - personne : « Je prends »
  #   - moi      : « ✓ @moi », appuyé — le toucher laisse l'article
  #   - un autre : « @pseudo » — le toucher reprend l'article
  # @param menu [Menu]
  # @param item [GroceryItem]
  # @param claim_state [String] "free", "mine" ou "other" (GroceryItem#claim_state_for)
  def grocery_item_claim_button(menu, item, claim_state)
    path = claim_menu_grocery_item_path(menu, item)
    options = { form_class: "button_to grocery-claim-form" }

    case claim_state
    when "free"
      button_to "Je prends", path, method: :patch, class: "btn btn-white grocery-claim-btn",
                                   "aria-label": "Je prends « #{item.name} »", **options
    when "mine"
      button_to path, method: :delete, class: "btn btn-primary grocery-claim-btn",
                      "aria-pressed": "true", "aria-label": "Laisser « #{item.name} »", **options do
        safe_join([ svg_icon(:check, size: 14), grocery_claim_btn_pseudo(current_user) ])
      end
    else
      button_to path, method: :patch, class: "btn btn-secondary grocery-claim-btn grocery-claim-btn--other",
                      "aria-label": "Prendre « #{item.name} » à la place de @#{item.claimed_by.username}", **options do
        grocery_claim_btn_pseudo(item.claimed_by)
      end
    end
  end

  # « @pseudo » dans un bouton de répartition. Le pseudo n'a pas de longueur
  # maximale : isolé dans son span, il se coupe d'une ellipse plutôt que
  # d'élargir le bouton jusqu'à écraser le nom de l'article (le nom complet
  # reste dans l'aria-label du bouton).
  # @param user [User]
  def grocery_claim_btn_pseudo(user)
    tag.span("@#{user.username}", class: "grocery-claim-btn-pseudo")
  end

  # Libellés du bouton de rayon, selon qu'il prend ou laisse.
  SECTION_CLAIM_LABELS = { take: "Tout prendre", leave: "Tout laisser" }.freeze

  # Bouton de répartition d'un rayon entier (mode « Répartir ») : « Tout prendre »
  # tant qu'il reste des articles libres, puis « Tout laisser » pour rendre les
  # siens. Rien quand le rayon est entièrement pris par d'autres. Teinté de la
  # couleur du rayon : il agit sur tout le rayon, pas sur un article.
  #
  # Les deux libellés sont rendus l'un sur l'autre, l'inactif invisible : le
  # bouton a toujours la largeur du plus long, d'un rayon à l'autre et quand il
  # change d'état — quelle que soit la police de l'appareil (cf. CSS). Le nom
  # accessible, lui, vient de l'aria-label.
  # @param menu [Menu]
  # @param category [String, nil]
  # @param claim_states [Array<String>] l'état de chaque ligne du rayon
  # @return [String, nil]
  def grocery_section_claim_button(menu, category, claim_states)
    method, action = if claim_states.include?("free")
      [ :patch, :take ]
    elsif claim_states.include?("mine")
      [ :delete, :leave ]
    end
    return unless method

    button_to claim_section_menu_grocery_items_path(menu),
              method: method, params: { category: category },
              class: "btn btn-category grocery-claim-btn grocery-section-claim-btn",
              "aria-label": "#{SECTION_CLAIM_LABELS[action]} : #{grocery_section_name(category)}",
              form_class: "button_to grocery-section-claim-form" do
      safe_join(SECTION_CLAIM_LABELS.map do |key, text|
        inactive = "grocery-section-claim-label--inactive" unless key == action
        tag.span(text, class: [ "grocery-section-claim-label", inactive ])
      end)
    end
  end
end
