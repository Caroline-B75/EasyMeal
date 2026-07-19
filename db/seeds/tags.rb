# Seed des tags de recettes.
# Idempotent : le tag_type est (re)positionné à chaque passage, donc une
# correction de catégorie est bien répercutée au re-seed (contrairement à
# find_or_create_by! dont le bloc ne s'exécute qu'à la création).

puts "  Création / mise à jour des tags..."

# Source unique : chaque tag_type (clé de l'enum Tag) → ses tags (en minuscules).
# Pas de catégorie « rapidité » : le catalogue filtre déjà par durée via « Temps max »
# (Recipe.with_total_time_lte, calculé sur prépa + cuisson).
# Méthode de cuisson : réduite aux critères de recherche utiles (le reste, trop
# matériel, alourdissait les filtres).
TAGS_BY_TYPE = {
  regime_alimentaire: [ "végétarien", "vegan", "healthy" ],
  cuisine_monde:      [ "française", "italienne", "espagnole", "grecque", "marocaine",
                        "libanaise", "indienne", "chinoise", "japonaise", "thaïlandaise",
                        "coréenne", "vietnamienne", "mexicaine", "américaine" ],
  occasion:           [ "apéritif", "entrée", "plat", "dessert", "goûter", "brunch",
                        "pique-nique", "petit-déjeuner", "salade" ],
  methode_cuisson:    [ "four", "poêle", "vapeur", "barbecue", "sans cuisson" ]
}.freeze

created = 0
updated = 0

TAGS_BY_TYPE.each do |tag_type, names|
  names.each do |name|
    tag = Tag.find_or_initialize_by(name: name.downcase)
    was_new = tag.new_record?
    tag.tag_type = tag_type

    if tag.changed?
      tag.save!
      was_new ? created += 1 : updated += 1
    end
  end
end

puts "  ✅ #{Tag.count} tags en base (#{created} créés, #{updated} mis à jour)"
