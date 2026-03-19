# Seeds pour les Recettes de test
# Utilise find_or_create_by! pour éviter les doublons

puts "  Création des recettes de test..."

# === RECETTES DE TEST ===

# Récupère les ingrédients existants (s'ils n'existent pas, on skip)
def find_ingredient(name)
  Ingredient.find_by("LOWER(name) LIKE ?", "%#{name.downcase}%")
end

# Récupère les tags existants
def find_tags(*names)
  Tag.where(name: names.map(&:downcase))
end

# --- Recette 1 : Pâtes Carbonara ---
carbonara = Recipe.find_or_create_by!(name: "Pâtes Carbonara") do |r|
  r.description = "La vraie recette italienne des pâtes à la carbonara, crémeuses et savoureuses."
  r.instructions = <<~INSTRUCTIONS
    1. Faire bouillir une grande casserole d'eau salée et cuire les pâtes al dente.

    2. Pendant ce temps, couper les lardons en petits morceaux et les faire revenir à la poêle sans matière grasse jusqu'à ce qu'ils soient dorés.

    3. Dans un bol, mélanger les jaunes d'œufs avec le parmesan râpé et un peu de poivre noir. Ajouter une louche d'eau de cuisson des pâtes pour tempérer.

    4. Égoutter les pâtes en gardant un peu d'eau de cuisson. Les verser immédiatement dans la poêle avec les lardons (feu éteint).

    5. Ajouter le mélange œufs-parmesan et mélanger rapidement pour enrober les pâtes. La chaleur des pâtes va cuire légèrement les œufs et créer une sauce crémeuse.

    6. Servir immédiatement avec du parmesan râpé et du poivre noir.
  INSTRUCTIONS
  r.default_servings = 4
  r.prep_time_minutes = 10
  r.cook_time_minutes = 15
  r.difficulty = :facile
  r.price = :economique
  r.diet = :omnivore
end

# Ajouter les ingrédients à la carbonara
if carbonara.preparations.empty?
  [
    { name: 'pâtes', quantity: 400 },
    { name: 'lardon', quantity: 200 },
    { name: 'œuf', quantity: 4 },
    { name: 'parmesan', quantity: 100 },
    { name: 'poivre', quantity: 2 }
  ].each do |prep|
    ingredient = find_ingredient(prep[:name])
    if ingredient
      carbonara.preparations.find_or_create_by!(ingredient: ingredient) do |p|
        p.quantity_base = prep[:quantity]
      end
    end
  end
end

carbonara.tags = find_tags('rapide', 'plat', 'facile', 'familial')
carbonara.save!

# --- Recette 2 : Salade Grecque ---
salade_grecque = Recipe.find_or_create_by!(name: "Salade Grecque") do |r|
  r.description = "Une salade fraîche et colorée, parfaite pour l'été avec des tomates, concombre et feta."
  r.instructions = <<~INSTRUCTIONS
    1. Laver et couper les tomates en quartiers.

    2. Éplucher le concombre et le couper en rondelles épaisses.

    3. Émincer l'oignon rouge en fines lamelles.

    4. Couper la feta en cubes.

    5. Dans un grand saladier, disposer tous les légumes, ajouter les olives noires et la feta.

    6. Préparer la vinaigrette : mélanger l'huile d'olive, le jus de citron, l'origan, le sel et le poivre.

    7. Arroser la salade de vinaigrette et servir frais.
  INSTRUCTIONS
  r.default_servings = 4
  r.prep_time_minutes = 15
  r.cook_time_minutes = 0
  r.difficulty = :facile
  r.price = :economique
  r.diet = :vegetarien
end

if salade_grecque.preparations.empty?
  [
    { name: 'tomate', quantity: 400 },
    { name: 'concombre', quantity: 200 },
    { name: 'oignon', quantity: 100 },
    { name: 'feta', quantity: 200 },
    { name: 'olive', quantity: 100 },
    { name: 'huile', quantity: 45 }
  ].each do |prep|
    ingredient = find_ingredient(prep[:name])
    if ingredient
      salade_grecque.preparations.find_or_create_by!(ingredient: ingredient) do |p|
        p.quantity_base = prep[:quantity]
      end
    end
  end
end

salade_grecque.tags = find_tags('végétarien', 'été', 'léger', 'sans cuisson', 'rapide')
salade_grecque.save!

# --- Recette 3 : Poulet Rôti aux Herbes ---
poulet_roti = Recipe.find_or_create_by!(name: "Poulet Rôti aux Herbes de Provence") do |r|
  r.description = "Un classique indémodable : poulet entier rôti au four avec des herbes de Provence."
  r.instructions = <<~INSTRUCTIONS
    1. Préchauffer le four à 200°C.

    2. Sortir le poulet du réfrigérateur 30 minutes avant la cuisson.

    3. Frotter le poulet avec de l'huile d'olive, du sel, du poivre et les herbes de Provence.

    4. Placer le poulet dans un plat à four avec les gousses d'ail non épluchées autour.

    5. Enfourner pour 1h15 à 1h30 selon la taille du poulet. Arroser régulièrement avec le jus de cuisson.

    6. Le poulet est cuit quand le jus qui s'écoule de la cuisse est clair.

    7. Laisser reposer 10 minutes avant de découper et servir.
  INSTRUCTIONS
  r.default_servings = 6
  r.prep_time_minutes = 15
  r.cook_time_minutes = 90
  r.difficulty = :moyen
  r.price = :moyen
  r.diet = :omnivore
  r.appliance = "Four"
end

if poulet_roti.preparations.empty?
  [
    { name: 'poulet', quantity: 1500 },
    { name: 'ail', quantity: 30 },
    { name: 'huile', quantity: 45 },
    { name: 'herbes', quantity: 6 },
    { name: 'sel', quantity: 10 },
    { name: 'poivre', quantity: 3 }
  ].each do |prep|
    ingredient = find_ingredient(prep[:name])
    if ingredient
      poulet_roti.preparations.find_or_create_by!(ingredient: ingredient) do |p|
        p.quantity_base = prep[:quantity]
      end
    end
  end
end

poulet_roti.tags = find_tags('four', 'plat', 'familial', 'automne', 'hiver')
poulet_roti.save!

# --- Recette 4 : Smoothie Bowl Tropical ---
smoothie_bowl = Recipe.find_or_create_by!(name: "Smoothie Bowl Tropical") do |r|
  r.description = "Un petit-déjeuner vitaminé et coloré avec des fruits tropicaux et des toppings gourmands."
  r.instructions = <<~INSTRUCTIONS
    1. La veille, couper la banane en rondelles et la mettre au congélateur.

    2. Dans un blender, mixer la banane congelée avec les morceaux de mangue et un peu de lait végétal jusqu'à obtenir une texture épaisse.

    3. Verser dans un bol.

    4. Décorer avec des fruits frais coupés, des copeaux de noix de coco, des graines de chia et du granola.

    5. Servir immédiatement.
  INSTRUCTIONS
  r.default_servings = 1
  r.prep_time_minutes = 10
  r.cook_time_minutes = 0
  r.difficulty = :facile
  r.price = :moyen
  r.diet = :vegan
end

if smoothie_bowl.preparations.empty?
  [
    { name: 'banane', quantity: 150 },
    { name: 'mangue', quantity: 100 },
    { name: 'lait', quantity: 50 },
    { name: 'noix de coco', quantity: 15 }
  ].each do |prep|
    ingredient = find_ingredient(prep[:name])
    if ingredient
      smoothie_bowl.preparations.find_or_create_by!(ingredient: ingredient) do |p|
        p.quantity_base = prep[:quantity]
      end
    end
  end
end

smoothie_bowl.tags = find_tags('vegan', 'brunch', 'healthy', 'sans cuisson', 'été')
smoothie_bowl.save!

# --- Recette 5 : Quiche Lorraine ---
quiche = Recipe.find_or_create_by!(name: "Quiche Lorraine") do |r|
  r.description = "La recette traditionnelle de la quiche lorraine aux lardons et à la crème."
  r.instructions = <<~INSTRUCTIONS
    1. Préchauffer le four à 180°C.

    2. Étaler la pâte brisée dans un moule à tarte et piquer le fond avec une fourchette.

    3. Faire revenir les lardons à la poêle sans matière grasse et les répartir sur le fond de tarte.

    4. Dans un bol, battre les œufs avec la crème fraîche, le sel, le poivre et la muscade.

    5. Verser ce mélange sur les lardons.

    6. Enfourner pour 35 à 40 minutes jusqu'à ce que la quiche soit dorée.

    7. Servir tiède avec une salade verte.
  INSTRUCTIONS
  r.default_servings = 6
  r.prep_time_minutes = 20
  r.cook_time_minutes = 40
  r.difficulty = :moyen
  r.price = :economique
  r.diet = :omnivore
  r.appliance = "Four"
end

if quiche.preparations.empty?
  [
    { name: 'pâte', quantity: 250 },
    { name: 'lardon', quantity: 200 },
    { name: 'œuf', quantity: 3 },
    { name: 'crème', quantity: 200 }
  ].each do |prep|
    ingredient = find_ingredient(prep[:name])
    if ingredient
      quiche.preparations.find_or_create_by!(ingredient: ingredient) do |p|
        p.quantity_base = prep[:quantity]
      end
    end
  end
end

quiche.tags = find_tags('four', 'plat', 'familial', 'comfort-food')
quiche.save!

puts "  ✅ #{Recipe.count} recettes en base"
