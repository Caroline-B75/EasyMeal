# Seed des recettes de démonstration.
#
# Une seule recette de démo (Pâtes Carbonara) : les autres recettes seront
# ajoutées en production. Pour en ajouter, compléter le tableau RECIPES ci-dessous.
#
# - Résolution d'ingrédient robuste : nom exact → alias exact → sous-chaîne (ordonnée),
#   avec alerte explicite si un terme reste introuvable (fini l'échec silencieux).
# - Idempotent : attributs, préparations (quantités) et tags sont resynchronisés au re-seed.
# - Les quantités sont exprimées dans l'unité de base de l'ingrédient
#   (g / ml / pièce / càc).

puts "  Création / mise à jour des recettes de démo..."

# Résout un ingrédient : nom exact d'abord, puis alias exact, puis sous-chaîne.
# L'ordre évite qu'une sous-chaîne trop large (« œuf » ⊂ « bœuf ») ne l'emporte.
def find_ingredient(term)
  query = term.downcase
  Ingredient.find_by("LOWER(name) = ?", query) ||
    Ingredient.where("aliases @> ?", [ query ].to_json).order(:id).first ||
    Ingredient.where("LOWER(name) LIKE ?", "%#{query}%").order(:id).first
end

# Résout un ingrédient et signale son absence (retourne nil si introuvable).
def resolve_ingredient(term, recipe_name)
  ingredient = find_ingredient(term)
  puts "    ⚠️  Ingrédient introuvable : « #{term} » (#{recipe_name})" unless ingredient
  ingredient
end

# Associe les tags par nom en signalant ceux qui n'existent pas (fini l'échec silencieux).
def set_tags(recipe, names)
  wanted = names.map(&:downcase)
  tags = Tag.where(name: wanted)
  missing = wanted - tags.map(&:name)
  puts "    ⚠️  Tags inconnus (#{recipe.name}) : #{missing.join(', ')}" if missing.any?
  recipe.tags = tags
end

# Crée ou met à jour une recette avec ses préparations et ses tags, de façon idempotente.
def upsert_recipe(spec)
  recipe = Recipe.find_or_initialize_by(name: spec[:name])
  recipe.assign_attributes(spec[:attributes])

  if recipe.new_record?
    # Une recette publiée doit avoir ≥ 1 ingrédient DÈS la 1re sauvegarde : on
    # construit les préparations en mémoire, sauvées en cascade avec la recette.
    spec[:ingredients].each do |term, quantity|
      ingredient = resolve_ingredient(term, spec[:name])
      recipe.preparations.build(ingredient: ingredient, quantity_base: quantity) if ingredient
    end
    recipe.save!
  else
    recipe.save!
    # Recette déjà persistée : upsert explicite des préparations (met à jour les quantités).
    spec[:ingredients].each do |term, quantity|
      ingredient = resolve_ingredient(term, spec[:name])
      next unless ingredient

      prep = Preparation.find_or_initialize_by(recipe: recipe, ingredient: ingredient)
      prep.quantity_base = quantity
      prep.save! if prep.changed?
    end
  end

  set_tags(recipe, spec[:tags])
  recipe.save!
end

RECIPES = [
  {
    name: "Pâtes Carbonara",
    attributes: {
      description: "La vraie recette italienne des pâtes à la carbonara, crémeuses et savoureuses.",
      instructions: <<~INSTRUCTIONS,
        Faire bouillir une grande casserole d'eau salée et cuire les pâtes al dente.
        Pendant ce temps, couper les lardons en petits morceaux et les faire revenir à la poêle sans matière grasse jusqu'à ce qu'ils soient dorés.
        Dans un bol, mélanger les jaunes d'œufs avec le parmesan râpé et un peu de poivre noir. Ajouter une louche d'eau de cuisson des pâtes pour tempérer.
        Égoutter les pâtes en gardant un peu d'eau de cuisson. Les verser immédiatement dans la poêle avec les lardons (feu éteint).
        Ajouter le mélange œufs-parmesan et mélanger rapidement pour enrober les pâtes. La chaleur des pâtes va cuire légèrement les œufs et créer une sauce crémeuse.
        Servir immédiatement avec du parmesan râpé et du poivre noir.
      INSTRUCTIONS
      default_servings: 4,
      prep_time_minutes: 10,
      cook_time_minutes: 15,
      difficulty: :facile,
      price: :economique,
      diet: :omnivore,
      meal_types: %w[lunch dinner]
    },
    ingredients: [ [ "pâtes", 400 ], [ "lardon", 200 ], [ "œuf", 4 ], [ "parmesan", 100 ], [ "poivre", 2 ] ],
    # « plat » a disparu avec la rubrique « Occasion » (cf. db/seeds/tags.rb) :
    # le moment du repas ci-dessus le dit déjà. Reste une cuisine du monde, pour
    # que le catalogue de développement ait au moins un filtre par tag à offrir.
    tags: [ "italienne" ]
  }
].freeze

RECIPES.each { |spec| upsert_recipe(spec) }

puts "  ✅ #{Recipe.count} recettes en base"
