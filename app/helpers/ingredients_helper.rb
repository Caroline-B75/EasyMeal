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

  # Trois décimales au plus et aucun zéro inutile : 0,55 et non 0,550. La virgule
  # est demandée explicitement — la locale fr du projet ne porte pas les formats
  # numériques, et un coefficient est écrit pour être lu en français.
  def format_coefficient(value)
    number_with_precision(value, precision: 3, strip_insignificant_zeros: true, separator: ",")
  end
end
