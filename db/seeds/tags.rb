# Seeds pour les Tags
# Utilise find_or_create_by! pour éviter les doublons

puts "  Création des tags..."

# Tags de rapidité
SPEED_TAGS = [ 'express', 'rapide', '30 minutes', 'longue cuisson' ].freeze

# Tags diététiques
DIETARY_TAGS = [ 'végétarien', 'vegan', 'léger', 'healthy' ].freeze

# Tags d'occasion
OCCASION_TAGS = [ 'apéritif', 'entrée', 'plat', 'dessert', 'goûter', 'brunch', 'pique-nique', 'fêtes', 'petit-déjeuner', 'batch cooking', 'convivial', 'anniversaire' ].freeze

# Tags de méthode de cuisson
COOKING_METHOD_TAGS = [ 'four', 'poêle', 'vapeur', 'cocotte', 'barbecue', 'sans cuisson', 'auto cuiseur', 'thermomix', 'micro-ondes', 'plancha', 'wok', 'friteuse', 'airfryer', 'mijoteuse' ].freeze

# Tags de saison
SEASON_TAGS = [ 'printemps', 'été', 'automne', 'hiver' ].freeze

# Tags autres
OTHER_TAGS = [ 'facile', 'familial' ].freeze

# Création des tags par catégorie
SPEED_TAGS.each do |name|
  Tag.find_or_create_by!(name: name.downcase) do |tag|
    tag.tag_type = :rapidite
  end
end

DIETARY_TAGS.each do |name|
  Tag.find_or_create_by!(name: name.downcase) do |tag|
    tag.tag_type = :regime_alimentaire
  end
end

OCCASION_TAGS.each do |name|
  Tag.find_or_create_by!(name: name.downcase) do |tag|
    tag.tag_type = :occasion
  end
end

COOKING_METHOD_TAGS.each do |name|
  Tag.find_or_create_by!(name: name.downcase) do |tag|
    tag.tag_type = :methode_cuisson
  end
end

SEASON_TAGS.each do |name|
  Tag.find_or_create_by!(name: name.downcase) do |tag|
    tag.tag_type = :saison
  end
end

OTHER_TAGS.each do |name|
  Tag.find_or_create_by!(name: name.downcase) do |tag|
    tag.tag_type = :autre
  end
end

puts "  ✅ #{Tag.count} tags en base"
