# Seed des ingrédients de base français.
# Les données sont externalisées dans db/seeds/data/ingredients.yml (éditable
# sans toucher au code) et chargées ici de façon IDEMPOTENTE : re-seeder met à
# jour les ingrédients existants (alias, saison, catégorie, unité) au lieu de les
# ignorer — contrairement à find_or_create_by! qui n'agit qu'à la création.

require "yaml"

DATA_FILE = Rails.root.join("db/seeds/data/ingredients.yml")

# Unité de base dérivée du groupe d'unités (source unique de vérité,
# cohérente avec la validation du modèle Ingredient).
BASE_UNIT_FOR = {
  "mass"   => "g",
  "volume" => "ml",
  "count"  => "piece",
  "spoon"  => "cac"
}.freeze

puts "🌱 Création / mise à jour des ingrédients de base..."

data = YAML.safe_load_file(DATA_FILE)

# Garde-fou : détecte les noms dupliqués dans le YAML (name est une clé unique).
all_names = data.values.flatten.map { |item| item.fetch("name") }
duplicates = all_names.tally.select { |_name, count| count > 1 }.keys
raise "Doublons de nom dans #{DATA_FILE.basename} : #{duplicates.join(', ')}" if duplicates.any?

created = 0
updated = 0

data.each do |category, items|
  Array(items).each do |item|
    unit = item.fetch("unit")
    base_unit = BASE_UNIT_FOR.fetch(unit) { raise "Unité inconnue '#{unit}' pour #{item['name']}" }

    # Recherche insensible à la casse, comme la validation d'unicité du modèle :
    # un ingrédient créé à la volée depuis une recette (« mangue » en minuscules)
    # doit être repris et renommé sous sa forme canonique. Un find_or_initialize_by
    # sur le nom exact en ferait un second enregistrement, aussitôt refusé par
    # cette validation — et la seed entière échouait.
    name = item.fetch("name")
    ingredient = Ingredient.find_by("LOWER(name) = ?", name.downcase) || Ingredient.new
    was_new = ingredient.new_record?

    ingredient.assign_attributes(
      name:          name,
      category:      category,
      unit_group:    unit,
      base_unit:     base_unit,
      # Normalise comme AttributeCleaner (tri + uniq) pour que le YAML puisse être
      # écrit dans un ordre naturel (ex. hiver [12,1,2,3]) sans casser l'idempotence.
      season_months: Array(item["season"]).map(&:to_i).uniq.sort,
      aliases:       item["aliases"] || [],
      # Absent = aucune conversion pièce ↔ masse pour cet ingrédient (voir
      # UnitConversionService). Un nil explicite, et non un défaut à 0 : re-seeder
      # doit pouvoir retirer un poids devenu faux.
      piece_weight_g: item["weight"]
    )

    if ingredient.changed?
      ingredient.save!
      was_new ? created += 1 : updated += 1
    end
  end
end

total = Ingredient.count
puts "\n✅ #{total} ingrédients en base (#{created} créés, #{updated} mis à jour)."
puts "\nRépartition par rayon :"
Ingredient.group(:category).count.sort_by { |_category, count| -count }.each do |category, count|
  puts "  - #{Ingredient.enum_label(:category, category)} : #{count}"
end
