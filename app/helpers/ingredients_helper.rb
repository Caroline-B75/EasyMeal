# frozen_string_literal: true

# Affichage des coefficients de conversion d'un ingrédient — et surtout du degré
# de confiance qu'on leur accorde.
#
# Une densité estimée par l'IA est juste « à peu près » : elle convertit des
# cuillères en grammes, donc elle pèse sur les quantités de la liste de courses.
# Elle se signale partout où elle se voit — la liste du catalogue, la fiche, le
# formulaire — jusqu'à ce qu'un humain l'ait confirmée en enregistrant le
# formulaire (cf. IngredientsController#ingredient_params).
module IngredientsHelper
  # Pastille « à vérifier », rendue seulement quand la densité vient de l'IA.
  # Même phrase que l'indication du formulaire, portée en title : la pastille
  # attire l'œil, le survol explique.
  def density_to_check_badge(ingredient)
    return unless ingredient.density_source_ai?

    tag.span("densité à vérifier", class: "badge badge-blue", title: t("ingredients.density_to_check"))
  end

  # Indication du champ densité : l'explication pour tous, et le rappel de
  # vérification quand la valeur affichée n'est qu'une estimation.
  def density_field_hint(ingredient)
    hint = "Facultatif — fait le pont quand une recette dose ce que le catalogue pèse " \
           "(1 c. à s. de farine ≈ 8 g). Sans objet pour les ingrédients en pièces."
    return hint unless ingredient.density_source_ai?

    "#{hint} #{t('ingredients.density_to_check')}"
  end

  # Destination du compteur « densités à vérifier » : il pose le filtre, et le
  # repose au clic suivant. Le reste de l'état de la page — filtres, tri — suit,
  # sauf `page` : la liste change, on la reprend au début.
  def density_check_toggle_path
    query = request.query_parameters.except("page")
    query = params[:to_check] == "true" ? query.except("to_check") : query.merge(to_check: "true")

    ingredients_path(query)
  end

  # En-tête de colonne cliquable du catalogue : un clic trie, un second inverse
  # le sens, une flèche dit lequel est en cours.
  #
  # Le lien reconduit tout ce qui est déjà posé — filtres, recherche — puisqu'il
  # ne fait que changer le tri ; il laisse en revanche tomber `page`, un tri
  # nouveau se lisant depuis le début.
  def ingredient_sort_link(column, label)
    active    = ingredient_sort_column == column
    ascending = active && ingredient_sort_ascending?
    arrow     = tag.span(ascending ? "▲" : "▼", class: "sort-arrow") if active
    query     = request.query_parameters.except("page")
                       .merge(sort: column, direction: ascending ? "desc" : "asc")

    link_to safe_join([ label, arrow ].compact, " "), ingredients_path(query),
            class: "sort-link#{' is-active' if active}"
  end

  # Indication du champ « groupe d'unités », rendue seulement quand une recette
  # emploie l'ingrédient — c'est-à-dire quand le champ est verrouillé. Sans elle,
  # un select grisé passerait pour une panne.
  def unit_group_lock_hint(ingredient)
    return unless ingredient.used_in_recipes?

    "Verrouillé — cet ingrédient est utilisé dans #{ingredient.recipes_usage_label} : " \
      "changer d'unité rendrait fausses les quantités déjà saisies."
  end

  # Les coefficients renseignés, écrits comme on les lit : « 300 g la pièce »,
  # « 0,55 g/ml ». Rend nil quand l'ingrédient n'en porte aucun, pour que la
  # fiche n'affiche pas une ligne vide.
  def conversion_coefficients(ingredient)
    coefficients = [
      ("#{format_coefficient(ingredient.piece_weight_g)} g la pièce" if ingredient.piece_weight_g.present?),
      ("#{format_coefficient(ingredient.density_g_per_ml)} g/ml" if ingredient.density_g_per_ml.present?)
    ].compact

    coefficients.presence&.to_sentence
  end

  private

  # Colonne de tri en cours, ramenée à celles que le catalogue sait trier —
  # même liste blanche que le scope `sorted_by`.
  def ingredient_sort_column
    Ingredient::SORT_COLUMNS.key?(params[:sort]) ? params[:sort] : Ingredient::DEFAULT_SORT
  end

  # Sens du tri en cours : croissant partout sauf demande explicite (même règle
  # que le scope `sorted_by`, qui ne connaît que « desc » et le reste).
  def ingredient_sort_ascending?
    params[:direction] != "desc"
  end

  # Trois décimales au plus et aucun zéro inutile : 0,55 et non 0,550. La virgule
  # est demandée explicitement — la locale fr du projet ne porte pas les formats
  # numériques, et un coefficient est écrit pour être lu en français.
  def format_coefficient(value)
    number_with_precision(value, precision: 3, strip_insignificant_zeros: true, separator: ",")
  end
end
