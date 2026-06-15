class IngredientMatcherService
  FUZZY_THRESHOLD = 0.3

  # Cherche un ingrédient existant en base par son nom.
  # Retourne un hash avec :exact et :fuzzy :
  #   { exact: #<Ingredient>, fuzzy: [] }   → match exact trouvé
  #   { exact: nil, fuzzy: [#<Ingredient>] } → match(es) approché(s)
  #   { exact: nil, fuzzy: [] }              → aucun match
  def self.match(name)
    normalized = name.to_s.strip.downcase
    return { exact: nil, fuzzy: [] } if normalized.blank?

    exact = Ingredient.where("LOWER(name) = ?", normalized).first
    return { exact: exact, fuzzy: [] } if exact

    fuzzy = fuzzy_search(normalized)
    { exact: nil, fuzzy: fuzzy }
  end

  private

  def self.fuzzy_search(normalized)
    # Utilise l'index trigram pg_trgm déjà en place sur ingredients.name
    # connection.quote protège contre l'injection SQL dans le ORDER BY dynamique
    quoted = ActiveRecord::Base.connection.quote(normalized)

    Ingredient
      .where("similarity(lower(name), lower(?)) > ?", normalized, FUZZY_THRESHOLD)
      .order(Arel.sql("similarity(lower(name), lower(#{quoted})) DESC"))
      .limit(3)
      .to_a
  end
end
