# Seeds pour les Tags
# Utilise find_or_create_by! pour éviter les doublons

puts "  Création des tags..."

# Tags de rapidité
SPEED_TAGS = %w[express].freeze

# Tags diététiques
DIETARY_TAGS = ['végétarien', 'vegan', 'léger', 'healthy'].freeze

# Tags d'occasion
OCCASION_TAGS = ['apéritif', 'entrée', 'plat', 'dessert', 'brunch', 'pique-nique', 'fêtes'].freeze

# Tags de méthode de cuisson
COOKING_METHOD_TAGS = ['four', 'poêle', 'vapeur', 'cocotte', 'barbecue', 'sans cuisson'].freeze

# Tags de saison
SEASON_TAGS = ['printemps', 'été', 'automne', 'hiver'].freeze

# Tags autres
OTHER_TAGS = ['facile', 'familial'].freeze

# Création des tags par catégorie
SPEED_TAGS.each do |name|
  Tag.find_or_create_by!(name: name.downcase) do |tag|
    tag.tag_type = :speed
  end
end

DIETARY_TAGS.each do |name|
  Tag.find_or_create_by!(name: name.downcase) do |tag|
    tag.tag_type = :dietary
  end
end

OCCASION_TAGS.each do |name|
  Tag.find_or_create_by!(name: name.downcase) do |tag|
    tag.tag_type = :occasion
  end
end

COOKING_METHOD_TAGS.each do |name|
  Tag.find_or_create_by!(name: name.downcase) do |tag|
    tag.tag_type = :cooking_method
  end
end

SEASON_TAGS.each do |name|
  Tag.find_or_create_by!(name: name.downcase) do |tag|
    tag.tag_type = :season
  end
end

OTHER_TAGS.each do |name|
  Tag.find_or_create_by!(name: name.downcase) do |tag|
    tag.tag_type = :other
  end
end

puts "  ✅ #{Tag.count} tags en base"
