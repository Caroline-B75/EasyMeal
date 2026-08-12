class IngredientMatcherService
  # Similarité trigram sur la chaîne entière : rattrape les fautes de frappe
  # (« tomatte » → « tomate »).
  FUZZY_THRESHOLD = 0.3

  # Similarité « par mots » : word_similarity cherche le meilleur fragment du
  # nom en base correspondant à la requête, ce qui rapproche « thym » de
  # « thym frais ». Plus généreuse que la précédente, donc seuil plus haut.
  WORD_THRESHOLD = 0.6

  # Quantificateurs que l'IA colle devant le nom réel de l'ingrédient
  # (« brin de thym », « gousse d'ail »). Comptés dans la similarité, ils la
  # font chuter sous le seuil et masquent des correspondances évidentes : on
  # cherche donc aussi avec la forme réduite.
  # « noix » en est volontairement absent : « noix de coco » est un ingrédient.
  QUANTIFIER_WORDS = %w[
    bocal boite botte bouquet branche brin cuillere cuilleree feuille filet
    gousse louche morceau pincee poignee pot rondelle sachet tete tige tranche
    trait verre zeste
  ].freeze

  # Quantificateur de tête, éventuellement précédé d'un nombre ou de « quelques »,
  # et suivi de « de » / « du » / « d' » : « 2 brins de thym », « quelques
  # feuilles de basilic », « gousse d'ail ».
  QUANTIFIER_PREFIX = /\A(?:quelques\s+)?(?:\d+(?:[.,\/]\d+)?\s*)?(?:#{QUANTIFIER_WORDS.join('|')})s?\s+d[eu']\s*/

  # Cherche un ingrédient existant en base par son nom.
  # Retourne un hash avec :exact et :fuzzy :
  #   { exact: #<Ingredient>, fuzzy: [] }   → match exact trouvé
  #   { exact: nil, fuzzy: [#<Ingredient>] } → match(es) approché(s)
  #   { exact: nil, fuzzy: [] }              → aucun match
  def self.match(name)
    normalized = name.to_s.strip.downcase
    return { exact: nil, fuzzy: [] } if normalized.blank?

    # Le nom tel quel d'abord, sa forme réduite ensuite : un ingrédient
    # réellement nommé « brin de thym » doit primer sur « thym ».
    candidates = [ normalized, strip_quantifier(normalized) ].uniq

    exact = candidates.lazy.filter_map { |candidate| exact_match(candidate) }.first
    return { exact: exact, fuzzy: [] } if exact

    { exact: nil, fuzzy: fuzzy_search(candidates.last) }
  end

  # Retire le quantificateur de tête (« brin de thym » → « thym »). Publique :
  # la recherche manuelle du panneau IA réduit sa requête de la même façon, pour
  # trouver ce que la détection automatique aurait trouvé. La détection travaille
  # sur une copie sans accents — « pincée », « boîte » — mais la coupe s'applique
  # au texte d'origine : les deux formes ont la même longueur.
  def self.strip_quantifier(name)
    found = QUANTIFIER_PREFIX.match(deaccent(name))
    return name unless found

    name[found.end(0)..].to_s.strip.presence || name
  end

  private

  # Un match exact vaut aussi sur les alias : c'est là que sont mémorisées les
  # associations confirmées à la main dans le panneau IA (« brin de thym » →
  # Thym frais). Sans cette lecture, cet apprentissage ne servirait à rien.
  # Le nom l'emporte sur l'alias : un ingrédient qui porte réellement ce nom
  # passe devant celui qui l'a seulement appris.
  def self.exact_match(name)
    Ingredient.where("LOWER(name) = ?", name).first ||
      Ingredient.where("aliases @> ?", [ name ].to_json).first
  end

  def self.fuzzy_search(name)
    # connection.quote protège contre l'injection SQL dans le ORDER BY dynamique
    quoted = ActiveRecord::Base.connection.quote(name)
    score  = "GREATEST(word_similarity(#{quoted}, lower(name)), similarity(lower(name), #{quoted}))"

    Ingredient
      .where("word_similarity(?, lower(name)) > ? OR similarity(lower(name), ?) > ?",
             name, WORD_THRESHOLD, name, FUZZY_THRESHOLD)
      .order(Arel.sql("#{score} DESC"))
      .limit(3)
      .to_a
  end

  # Décompose puis retire les marques diacritiques (é → e, î → i).
  def self.deaccent(text)
    text.unicode_normalize(:nfd).gsub(/\p{Mn}/, "")
  end
end
