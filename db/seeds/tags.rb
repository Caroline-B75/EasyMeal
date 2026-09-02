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
# Aucun tag ne doit reprendre une valeur des enums Recipe (diet, difficulty, price) :
# la fiche recette affiche déjà ces attributs (kicker régime + badges), un tag
# homonyme s'afficherait donc deux fois.
# Pas de catégorie « occasion » (apéritif, entrée, plat, dessert...) pour la même
# raison : ce classement est celui des moments du repas (MealTypes), un attribut
# de la recette — les filtres du catalogue le proposent déjà via « Moment du
# repas ». La rubrique a donc été retirée de l'enum Tag#tag_type le 02/09/2026,
# et ses tags supprimés en base par la migration DeleteOccasionTags.
TAGS_BY_TYPE = {
  regime_alimentaire: [ "végétarien", "healthy" ],
  cuisine_monde:      [ "française", "italienne", "espagnole", "grecque", "marocaine",
                        "libanaise", "indienne", "chinoise", "japonaise", "thaïlandaise",
                        "coréenne", "vietnamienne", "mexicaine", "américaine" ],
  methode_cuisson:    [ "four", "poêle", "vapeur", "barbecue", "sans cuisson" ],
  # La saison d'une recette n'est pas celle de ses ingrédients : le catalogue
  # sait déjà filtrer sur les mois de disponibilité (Ingredient#season_months),
  # mais rien ne dit qu'une soupe se mange en hiver et un gaspacho en été. C'est
  # ce que ces quatre tags ajoutent — un classement de recette, pas de produit.
  saison:             [ "printemps", "été", "automne", "hiver" ]
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
