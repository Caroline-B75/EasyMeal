# frozen_string_literal: true

# Ce que le catalogue d'ingrédients demande à un ingrédient : savoir combien de
# recettes l'emploient, et se laisser ranger.
#
# Le décompte n'est pas qu'une colonne d'affichage : c'est lui qui dit si
# l'ingrédient peut encore partir (suppression) ou changer d'unité — les deux
# verrous portés par Ingredient lui-même.
module IngredientCatalog
  extend ActiveSupport::Concern

  # Colonnes triables du catalogue et l'expression SQL de chacune (cf. le scope
  # `sorted_by`). La clé est ce qui circule dans l'URL, donc aussi ce que les
  # en-têtes du catalogue passent au helper de tri.
  #
  # Le nom se trie désaccentué, pour qu'« Échalote » tombe entre « Ébly » et
  # « Écrevisse » plutôt qu'après tous les Z. Le rayon, lui, se trie sur la
  # valeur de l'enum : c'est l'ordre du magasin, celui qui range déjà la liste
  # de courses, et non l'ordre alphabétique des libellés.
  SORT_COLUMNS = {
    "name" => "unaccent(LOWER(ingredients.name))",
    "category" => "ingredients.category",
    "recipes_count" => "recipes_count"
  }.freeze

  # Tri appliqué tant qu'aucun autre n'est demandé — et départage des ex æquo.
  DEFAULT_SORT = "name"

  included do
    # Tri du catalogue, demandé par ?sort=&direction=. Colonne et sens ne sont
    # jamais interpolés depuis les params : SORT_COLUMNS fait liste blanche, tout
    # le reste retombe sur le tri par défaut.
    #
    # `recipes_count` désigne l'alias posé par with_recipes_count, qu'il faut donc
    # avoir appliqué pour trier là-dessus.
    scope :sorted_by, ->(column, direction) {
      column = SORT_COLUMNS.key?(column.to_s) ? column.to_s : DEFAULT_SORT
      order  = "#{SORT_COLUMNS[column]} #{direction.to_s == 'desc' ? 'DESC' : 'ASC'}"
      # Le nom départage les ex æquo — sans cet ordre total, deux pages
      # consécutives pourraient montrer deux fois le même ingrédient.
      order += ", #{SORT_COLUMNS[DEFAULT_SORT]} ASC" unless column == DEFAULT_SORT

      reorder(Arel.sql(order))
    }

    # Charge, avec chaque ingrédient, le nombre de recettes qui l'emploient.
    #
    # Sous-requête scalaire plutôt que `left_joins(:preparations).group(:id)` : le
    # GROUP BY ferait rendre un hash au `count` de Pagy, qui pagine l'index.
    scope :with_recipes_count, -> {
      select(
        "ingredients.*",
        "(SELECT COUNT(*) FROM preparations WHERE preparations.ingredient_id = ingredients.id) AS recipes_count"
      )
    }
  end

  # Nombre de recettes qui emploient cet ingrédient. Le scope
  # `with_recipes_count` l'a déjà compté en base pour toute une page ; ailleurs,
  # on interroge l'association. Une recette ne peut porter qu'une préparation
  # par ingrédient (unicité côté Preparation) : compter les préparations, c'est
  # bien compter les recettes.
  def recipes_count
    self["recipes_count"] || preparations.count
  end

  # Un ingrédient déjà employé est retenu par ses recettes : ni suppression
  # (dependent: :restrict_with_error) ni changement d'unité.
  def used_in_recipes?
    recipes_count.positive?
  end

  # « 1 recette », « 3 recettes » — le décompte écrit d'une seule façon partout
  # où l'emploi retient l'ingrédient : refus de suppression, verrou du groupe
  # d'unités. (Le catalogue, lui, n'affiche que le nombre.)
  def recipes_usage_label
    I18n.t("ingredients.recipes_count", count: recipes_count)
  end
end
