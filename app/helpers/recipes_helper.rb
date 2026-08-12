# Helper pour les recettes
module RecipesHelper
  # Libellés lisibles des sources d'import d'un brouillon (source_type en base).
  DRAFT_SOURCE_LABELS = { "url" => "Lien", "photo" => "Photo" }.freeze

  # Libellé lisible de la source d'un brouillon importé (badge de la liste).
  def draft_source_label(source_type)
    DRAFT_SOURCE_LABELS[source_type] || source_type.to_s.upcase
  end

  # Icône associée à la source d'import (lien internet vs photo).
  def draft_source_icon(source_type)
    source_type == "photo" ? :image : :link
  end

  # Infobulle des deux portes d'entrée vers la page d'origine d'un import :
  # le badge de la liste des brouillons et le bandeau du formulaire de validation.
  SOURCE_LINK_TITLE = "Ouvrir la page d'origine dans un nouvel onglet".freeze

  # Badge de source d'un brouillon importé (liste des imports).
  # Quand l'import vient d'un lien dont l'URL est connue, le badge devient un
  # vrai lien : pendant la validation, un clic rouvre la page d'origine pour
  # comparer. Les autres cas — import photo, ou vieux brouillon URL sans
  # source_url — gardent un simple libellé.
  def draft_source_badge(recipe)
    content = safe_join([
      svg_icon(draft_source_icon(recipe.source_type), size: 11),
      draft_source_label(recipe.source_type)
    ])

    return content_tag(:span, content, class: "badge badge--source") unless recipe.imported_from_link?

    link_to content, recipe.source_url, **source_link_options("badge badge--source badge--source-link")
  end

  # La même page d'origine, mais adresse en toutes lettres : bandeau de référence
  # posé en tête du formulaire de validation d'un brouillon.
  def draft_source_url_link(recipe)
    link_to recipe.source_url, recipe.source_url, **source_link_options("rf-source__link")
  end

  # Politique commune des liens sortants vers la page d'origine : nouvel onglet
  # (le formulaire en cours de saisie ne doit jamais être remplacé), rel de
  # sécurité, et infobulle qui annonce l'ouverture.
  def source_link_options(css_class)
    { class: css_class, target: "_blank", rel: "noopener noreferrer", title: SOURCE_LINK_TITLE }
  end

  # Options du sélecteur de tri de la liste des brouillons. La liste des tris
  # vit dans RecipeDraftsController::SORTS, qui les applique : la vue l'affiche
  # sans jamais recopier ni les clés ni les libellés.
  def draft_sort_options(selected)
    options_for_select(RecipeDraftsController::SORTS.map { |key, label| [ label, key ] }, selected)
  end

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

  # Texte compact du badge temps d'une mini-carte (UC7, ex « 35 min ») — nil
  # si aucun temps n'est renseigné : le badge ne doit alors pas s'afficher.
  # Volontairement sans conversion en heures (contrairement à format_prep_time) :
  # le badge reste un repère rapide, pas une durée précise.
  # @return [String, nil]
  def total_time_badge(recipe)
    total = recipe.total_time_minutes
    "#{total} min" if total.positive?
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

  # Badge de régime — pastille colorée + libellé (sans emoji : rendu premium et
  # cohérent quel que soit l'OS ; la couleur porte l'identité du régime).
  def diet_badge(diet)
    colors = {
      "omnivore" => "badge-beige",
      "vegetarien" => "badge-green",
      "vegan" => "badge-green",
      "pescetarien" => "badge-blue"
    }
    color_class = colors[diet] || "badge-orange"

    content_tag :span, diet.humanize, class: "badge #{color_class}"
  end

  # === Boutons d'ajout / retrait du brouillon (UC2/UC7) ===

  # Destination annoncée par le tooltip d'un bouton d'ajout / retrait du
  # brouillon. En contexte de moment (catalogue filtré, UC7), elle nomme le
  # moment réellement visé — « aux goûters du menu à valider » ; sinon le menu
  # tout court. Partagée par le bouton compact des cartes du catalogue
  # (_draft_button) et le CTA de la fiche recette (_draft_cta), qui ne
  # divergent que par ce qui la précède.
  # @param meal_type [String, nil] moment du contexte
  # @param action [Symbol] :add ou :remove — la préposition suit le sens
  # @return [String]
  def draft_toggle_destination(meal_type, action)
    adding = action == :add
    return adding ? "au menu à valider" : "du menu à valider" if meal_type.blank?

    "#{adding ? 'aux' : 'des'} #{MealTypes.inline_label(meal_type)} du menu à valider"
  end

  # === Rail « menu à valider » du catalogue (UC2) ===

  # Compteur du rail : brouillon encore vide, ou nombre de recettes retenues.
  # Pluriel écrit à la main (comme ailleurs dans le projet) : ActionView#pluralize
  # s'appuie sur les inflexions de la locale courante, et :fr n'en définit aucune
  # — il rendrait « 3 recette ».
  def draft_rail_label(count)
    return "Aucune recette dans le menu" if count.zero?

    "#{count} recette#{'s' if count > 1} dans le menu"
  end

  # Message de confirmation d'un changement du brouillon depuis le catalogue —
  # flash des réponses Turbo Stream toggle_in_draft et remove_from_draft.
  # @param recipe_name [String] nom de la recette ajoutée / retirée
  # @param count [Integer] nombre de repas du brouillon après l'opération
  # @param added [Boolean] sens de l'opération
  # @param draft_created [Boolean] le toggle vient-il de démarrer le brouillon ?
  def draft_change_notice(recipe_name:, count:, added:, draft_created: false)
    suffix = "(#{count} recette#{'s' if count != 1})"
    return "\"#{recipe_name}\" retirée du menu à valider #{suffix}" unless added

    if draft_created
      "Menu à valider démarré avec \"#{recipe_name}\" #{suffix}"
    else
      "\"#{recipe_name}\" ajoutée au menu à valider #{suffix}"
    end
  end

  # === Helpers pour la fiche recette ===

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

  # Srcset Cloudinary 1x/2x : sert la résolution adaptée à la densité de l'écran
  # (nette sur les écrans retina sans surcharger les écrans classiques).
  # width/height = taille d'affichage 1x (la variante 2x est calculée automatiquement).
  def cloudinary_photo_srcset(photo, width:, height:, crop: :fill)
    return nil unless photo.attached?

    url_1x = cloudinary_photo_url(photo, width: width, height: height, crop: crop)
    url_2x = cloudinary_photo_url(photo, width: width * 2, height: height * 2, crop: crop)
    "#{url_1x} 1x, #{url_2x} 2x"
  end
end
