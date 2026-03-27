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

    icon = icons[diet] || inline_svg("cook-book", css_class: "icon-sm", color: "currentColor")
    color_class = colors[diet] || "badge-orange"

    content_tag :span, class: "badge #{color_class}" do
      safe_join([icon, " #{diet.humanize}"])
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

    content_tag :span, symbols[price] || "€", class: "badge badge-beige"
  end

  # === Helpers pour le hero sombre de la fiche recette ===

  # Badge sur fond sombre (hero) — variantes : :default, :green, :amber
  def show_hero_badge(text, variant = :default)
    css = case variant
          when :green then "rs-badge rs-badge--green"
          when :amber then "rs-badge rs-badge--amber"
          else "rs-badge"
          end
    content_tag :span, text, class: css
  end

  # Détermine la variante de badge pour un régime alimentaire
  def badge_variant_for_diet(diet)
    case diet
    when "vegetarien", "vegan" then :green
    else :default
    end
  end

  # Détermine la variante de badge pour un prix
  def price_badge_variant(price)
    price == "economique" ? :amber : :default
  end

  # Distribution des notes pour l'histogramme (hash {1=>count, 2=>count, ...})
  def review_distribution(recipe)
    recipe.reviews.group(:rating).count
  end

  # Génère une URL Cloudinary avec transformations à la volée.
  # Contrairement à .variant(), cette approche n'uploade PAS une nouvelle image :
  # Cloudinary transforme via l'URL et met en cache le résultat.
  #
  # crop: :limit  → réduit à l'intérieur de W×H sans agrandir (= resize_to_limit)
  # crop: :fill   → remplit exactement W×H en recadrant (= resize_to_fill)
  def cloudinary_photo_url(photo, width:, height:, crop: :limit)
    return nil unless photo.attached?

    Cloudinary::Utils.cloudinary_url(
      photo.blob.key,
      width: width,
      height: height,
      crop: crop,
      fetch_format: :auto,
      quality: :auto
    )
  end
end
