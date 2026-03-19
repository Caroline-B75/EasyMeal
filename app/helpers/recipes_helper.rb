# Helper pour les recettes
module RecipesHelper
  # Retourne le texte formaté du temps de préparation
  def format_prep_time(minutes)
    return "Non renseigné" if minutes.blank? || minutes.zero?

    hours = minutes / 60
    mins = minutes % 60

    if hours > 0 && mins > 0
      "#{hours}h#{mins}"
    elsif hours > 0
      "#{hours}h"
    else
      "#{mins} min"
    end
  end

  # Retourne le temps total (préparation + cuisson)
  def format_total_time(recipe)
    total = recipe.total_time_minutes
    return "Non renseigné" if total.zero?
    format_prep_time(total)
  end

  # Retourne les étoiles affichées pour la note moyenne
  # rating_avg est un decimal (ex: 4.3)
  def rating_stars(rating_avg)
    full_stars = rating_avg.floor
    half_star = (rating_avg - full_stars) >= 0.5 ? 1 : 0
    empty_stars = 5 - full_stars - half_star

    ("★" * full_stars) +
    ("⯨" * half_star) +
    ("☆" * empty_stars)
  end

  # Badge de régime avec icône et couleur
  def diet_badge(diet)
    icons = {
      "omnivore" => "🍖",
      "vegetarien" => "🥕",
      "vegan" => "🌱",
      "pescetarien" => "🐟"
    }

    colors = {
      "omnivore" => "badge-beige",
      "vegetarien" => "badge-green",
      "vegan" => "badge-green",
      "pescetarien" => "badge-blue"
    }

    icon = icons[diet] || "🍽️"
    color_class = colors[diet] || "badge-orange"

    content_tag :span, class: "badge #{color_class}" do
      "#{icon} #{diet.humanize}"
    end
  end

  # Badge de difficulté avec couleur
  def difficulty_badge(difficulty)
    return content_tag(:span, "Non renseignée", class: "badge badge-beige") if difficulty.nil?

    colors = {
      "facile" => "badge-green",
      "moyen" => "badge-orange",
      "difficile" => "badge-red"
    }

    content_tag :span, difficulty.humanize, class: "badge #{colors[difficulty] || 'badge-beige'}"
  end

  # Badge de prix avec symboles €
  def price_badge(price)
    return content_tag(:span, "Non renseigné", class: "badge badge-beige") if price.nil?

    symbols = {
      "economique" => "€",
      "moyen" => "€€",
      "cher" => "€€€"
    }

    content_tag :span, symbols[price] || "€", class: "badge badge-orange"
  end

  # Retourne la classe CSS pour l'icône de favori
  def favorite_icon_class(is_favorited)
    is_favorited ? "icon-favorited" : "icon-favorite"
  end

  # Texte du bouton favori
  def favorite_button_text(is_favorited)
    is_favorited ? "★ Retirer des favoris" : "☆ Ajouter aux favoris"
  end
end
