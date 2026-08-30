# Seed des ingrédients de base français.
# Les données sont externalisées dans db/seeds/data/ingredients.yml (éditable
# sans toucher au code) et chargées ici de façon IDEMPOTENTE : re-seeder met à
# jour les ingrédients existants (alias, saison, catégorie, unité) au lieu de les
# ignorer — contrairement à find_or_create_by! qui n'agit qu'à la création.

require "yaml"

DATA_FILE = Rails.root.join("db/seeds/data/ingredients.yml")

# Unité de base dérivée du groupe d'unités. La table vit dans Units, avec le
# reste du vocabulaire des unités : la seed s'y branche au lieu de la recopier.
BASE_UNIT_FOR = Units::BASE_UNITS

# Le nom de la pièce, tel que le YAML l'écrit, ramené aux deux colonnes qui le
# stockent. Deux formes acceptées, parce que le français n'accorde pas tout de
# la même façon :
#
#   piece: "tranche"                → tranche / tranches (la règle régulière)
#   piece: [maquereau, maquereaux]  → pluriel explicite
#   piece: [gambas, gambas]         → invariable
#
# Le pluriel reste nul dans le cas courant : il ne se renseigne que là où le
# « s » ne suffit pas, et c'est cette rareté qui rend le YAML lisible.
def piece_label_attributes(value)
  singular, plural = Array(value)

  { piece_label: singular.presence, piece_label_plural: plural.presence }
end

puts "🌱 Création / mise à jour des ingrédients de base..."

data = YAML.safe_load_file(DATA_FILE)

# La clé `retired` n'est pas un rayon mais la liste des ingrédients à retirer du
# catalogue (cf. l'en-tête du YAML) : elle est traitée à part, après les upserts.
retired_names = Array(data.delete("retired"))

# Garde-fou : détecte les noms dupliqués dans le YAML (name est une clé unique).
all_names = data.values.flatten.map { |item| item.fetch("name") }
duplicates = all_names.tally.select { |_name, count| count > 1 }.keys
raise "Doublons de nom dans #{DATA_FILE.basename} : #{duplicates.join(', ')}" if duplicates.any?

# Second garde-fou : un nom ne peut pas être à la fois servi et retiré — la seed
# le recréerait à chaque passage, juste après l'avoir supprimé.
still_served = all_names.map(&:downcase) & retired_names.map(&:downcase)
raise "Retirés mais toujours servis dans #{DATA_FILE.basename} : #{still_served.join(', ')}" if still_served.any?

created = 0
updated = 0
# Ingrédients que la base refuse d'aligner sur le fichier : comptés à part et
# nommés un par un, pour qu'un catalogue partiellement à jour se voie.
skipped = 0

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
      piece_weight_g: item["weight"],
      # Le volume d'une pièce, jumeau du poids pour ce qui se verse : une brique
      # de lait contient 1 L. Même règle de nullité — re-seeder doit pouvoir
      # retirer une contenance devenue fausse.
      piece_volume_ml: item["volume"],
      # Comment la pièce s'appelle, et par là même : cet ingrédient s'achète-t-il
      # à la pièce ? Le nom est l'interrupteur (cf. PieceUnit).
      **piece_label_attributes(item["piece"]),
      # Même règle pour la densité, dont la provenance est indissociable (cf. les
      # validations d'Ingredient) : ce qui est écrit dans le YAML est curaté, donc
      # réputé vérifié. Re-seeder écrase ainsi une estimation de l'IA par la
      # valeur curatée — c'est bien le but — et efface la provenance d'une densité
      # retirée.
      density_g_per_ml: item["density"],
      density_source:   (item["density"].present? ? :manual : nil)
    )

    if ingredient.changed?
      begin
        ingredient.save!
        was_new ? created += 1 : updated += 1
      rescue ActiveRecord::RecordInvalid => error
        # Le fichier et la base ont divergé sur un ingrédient que le modèle
        # refuse désormais de réaligner — typiquement un ingrédient créé à la
        # volée depuis une recette, dans un autre groupe d'unités que celui du
        # catalogue, et depuis employé par une recette : changer son unité
        # rendrait fausses les quantités déjà saisies (cf. la validation
        # `unit_group_frozen_once_used` d'Ingredient).
        #
        # On le signale et on continue, comme pour un retrait impossible plus
        # bas : arbitrer un tel conflit demande de relire les recettes
        # concernées, ce qui n'est pas le travail d'une seed. Sans ce filet, un
        # seul ingrédient divergent empêchait les 585 autres d'être mis à jour —
        # et, le jour où la seed a tourné en post-déploiement, faisait échouer
        # la mise en ligne entière (30/08/2026).
        skipped += 1
        puts "  ⚠️  « #{name} » n'a pas pu être mis à jour : #{error.record.errors.full_messages.join(', ')}"
      end
    end
  end
end

# Retrait des ingrédients sortis du catalogue. Après les upserts, et pas avant :
# leurs remplaçants doivent exister en base au moment où on lit l'avertissement.
#
# Une ligne de courses garde son nom sans son ingrédient (has_many :nullify), mais
# une recette ne peut pas perdre le sien : `restrict_with_error` fait échouer le
# destroy, et la seed se contente alors de signaler. C'est volontaire — arbitrer
# quelle découpe remplace « Canard » dans une recette existante n'est pas le
# travail d'une seed.
removed = 0
retired_names.each do |name|
  ingredient = Ingredient.find_by("LOWER(name) = ?", name.downcase)
  next if ingredient.nil?

  if ingredient.destroy
    removed += 1
  else
    recipes = ingredient.recipes.pluck(:name).first(3)
    puts "  ⚠️  « #{name} » est encore utilisé (#{recipes.join(', ')}…) : à réaffecter à la main."
  end
end

total = Ingredient.count
puts "\n✅ #{total} ingrédients en base (#{created} créés, #{updated} mis à jour, #{removed} retirés)."
puts "⚠️  #{skipped} ingrédient(s) laissés en l'état — voir les avertissements ci-dessus." if skipped.positive?
puts "\nRépartition par rayon :"
Ingredient.group(:category).count.sort_by { |_category, count| -count }.each do |category, count|
  puts "  - #{Ingredient.enum_label(:category, category)} : #{count}"
end
