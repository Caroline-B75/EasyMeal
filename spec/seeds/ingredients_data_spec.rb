# frozen_string_literal: true

require "rails_helper"

# Le catalogue d'ingrédients est une donnée de production éditée à la main : une
# faute de frappe dans le YAML ne se voit qu'au `db:seed`, c'est-à-dire au
# déploiement. Ces exemples le relisent en CI, sans toucher la base — ils ne
# vérifient pas que la seed tourne, mais que ce qu'elle va écrire est valide.
#
# Trois familles de pièges, tous rencontrés :
#   - la casse d'un alias : le matcher compare en JSONB (`aliases @> ["…"]`),
#     donc « choux de Bruxelles » stocké avec sa majuscule n'est jamais trouvé ;
#   - un alias porté par deux ingrédients : le matcher en choisit un au hasard ;
#   - un poids ou une densité posé sur un groupe d'unités qui ne le supporte
#     pas : la validation du modèle refuse l'enregistrement, la seed s'arrête.
RSpec.describe "db/seeds/data/ingredients.yml" do
  data     = YAML.safe_load_file(Rails.root.join("db/seeds/data/ingredients.yml"))
  retired  = Array(data.delete("retired"))
  entries  = data.flat_map { |category, items| Array(items).map { |item| item.merge("category" => category) } }

  it "n'est pas vide" do
    expect(entries.size).to be > 100
  end

  it "ne range les ingrédients que dans des rayons connus" do
    expect(data.keys).to all(be_in(Ingredient.categories.keys))
  end

  it "ne nomme jamais deux fois le même ingrédient" do
    duplicates = entries.map { |entry| entry.fetch("name").downcase }.tally.select { |_name, count| count > 1 }.keys

    expect(duplicates).to be_empty
  end

  it "n'écrit les alias qu'en minuscules" do
    # Le matcher cherche l'alias downcasé : une majuscule le rend introuvable.
    uppercased = entries.flat_map { |entry| Array(entry["aliases"]).reject { |a| a == a.downcase } }

    expect(uppercased).to be_empty
  end

  it "ne donne jamais le même alias à deux ingrédients" do
    owners = Hash.new { |hash, key| hash[key] = [] }
    entries.each { |entry| Array(entry["aliases"]).each { |a| owners[a] << entry["name"] } }
    shared = owners.select { |_alias_name, names| names.size > 1 }

    expect(shared).to be_empty, "alias partagés : #{shared.inspect}"
  end

  it "ne donne jamais à un ingrédient l'alias d'un autre ingrédient" do
    # Un alias homonyme d'un nom réel serait toujours perdant (exact_match
    # regarde les noms avant les alias) : autant ne pas l'écrire.
    names = entries.map { |entry| entry.fetch("name").downcase }.to_set
    colliding = entries.flat_map { |entry| Array(entry["aliases"]).select { |a| names.include?(a) } }

    expect(colliding).to be_empty
  end

  it "ne sert pas un ingrédient qu'il retire par ailleurs" do
    served = entries.map { |entry| entry.fetch("name").downcase }

    expect(served & retired.map(&:downcase)).to be_empty
  end

  it "n'emploie que des groupes d'unités connus" do
    expect(entries.map { |entry| entry.fetch("unit") }).to all(be_in(Units::BASE_UNITS.keys))
  end

  it "décrit des ingrédients que le modèle accepte" do
    invalid = entries.filter_map do |entry|
      unit = entry.fetch("unit")
      ingredient = Ingredient.new(
        name:             entry.fetch("name"),
        category:         entry.fetch("category"),
        unit_group:       unit,
        base_unit:        Units::BASE_UNITS.fetch(unit),
        season_months:    Array(entry["season"]),
        aliases:          Array(entry["aliases"]),
        piece_weight_g:   entry["weight"],
        density_g_per_ml: entry["density"],
        density_source:   (entry["density"].present? ? :manual : nil)
      )
      # L'unicité du nom se joue en base : elle est déjà couverte par l'absence
      # de doublons dans le fichier, testée plus haut.
      ingredient.valid?
      next if ingredient.errors.excluding(:name).empty?

      "#{entry['name']} : #{ingredient.errors.excluding(:name).full_messages.join(', ')}"
    end

    expect(invalid).to be_empty, invalid.join("\n")
  end
end
