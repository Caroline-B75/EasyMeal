# frozen_string_literal: true

# Élagage du catalogue de tags du 05/09/2026.
#
# Le seed (db/seeds/tags.rb) est additif : il crée et corrige, il ne supprime
# jamais. Les tags écartés d'une de ses listes survivent donc en base — et
# continuent de s'afficher dans le formulaire de recette comme dans les filtres
# du catalogue. C'est cette migration qui les retire, pour les trois raisons
# ci-dessous.
#
# Suppression par NOM et non par rubrique : deux des rangs concernés n'existent
# plus dans l'enum Tag#tag_type, et le nom est de toute façon ce que la règle
# vise (un tag « végétarien » reste un doublon quelle que soit sa rubrique).
#
# SQL direct plutôt que les modèles : une migration doit rester lisible par les
# versions futures du code, qui ne connaîtront plus ces rangs.
class DeleteRetiredTags < ActiveRecord::Migration[8.1]
  RETIRED_TAGS = [
    # Redisait Recipe#diet, que la fiche recette affiche déjà en kicker : la
    # recette portait deux fois la même information. C'est la règle inscrite en
    # tête du seed — aucun tag ne reprend une valeur d'un enum de Recipe.
    "végétarien",

    # Mélangeait deux questions que la rubrique « Nutrition » sépare désormais :
    # peu calorique (« léger ») d'un côté, complet (« équilibré ») de l'autre.
    # Aucun report automatique possible — laquelle des deux vaut pour une recette
    # donnée ne se devine pas : les recettes concernées repartent sans tag.
    "healthy",

    # Ancienne rubrique « Rapidité », retirée de l'enum au même commit : le
    # catalogue filtre déjà la durée via « Temps max » (Recipe.with_total_time_lte,
    # calculé sur prépa + cuisson), ces tags-là ne triaient plus rien.
    "30 minutes", "express", "longue cuisson", "familial",

    # Méthodes de cuisson trop matérielles : elles décrivent l'équipement de la
    # cuisine, pas un critère de recherche de recette. Le seed ne garde que les
    # cinq qui trient vraiment (four, poêle, vapeur, barbecue, sans cuisson).
    "airfryer", "thermomix", "mijoteuse", "friteuse", "micro-ondes",
    "plancha", "cocotte", "wok", "auto cuiseur"
  ].freeze

  # Rang qu'occupait la rubrique « Rapidité » dans l'enum Tag#tag_type.
  RAPIDITE = 4

  def up
    names = RETIRED_TAGS.map { |name| connection.quote(name) }.join(", ")

    # La jointure d'abord : recipe_tags.tag_id porte une clé étrangère vers tags.
    execute <<~SQL.squish
      DELETE FROM recipe_tags
      WHERE tag_id IN (SELECT id FROM tags WHERE name IN (#{names}))
    SQL

    execute "DELETE FROM tags WHERE name IN (#{names})"

    # Filet : un tag saisi à la main dans l'ancienne rubrique « Rapidité » que
    # la liste ci-dessus ne connaîtrait pas. On le déclasse plutôt que de le
    # supprimer — son nom, lui, a été choisi par quelqu'un. tag_type NULL le
    # range sous « Autre » (Tag.grouped_by_type) au lieu de lui laisser porter
    # un rang que le modèle ne sait plus lire.
    execute "UPDATE tags SET tag_type = NULL WHERE tag_type = #{RAPIDITE}"
  end

  def down
    # Des tags supprimés et leur répartition sur les recettes ne se devinent pas.
    raise ActiveRecord::IrreversibleMigration
  end
end
