# frozen_string_literal: true

module Menus
  # Tire au hasard jusqu'à `count` recettes DISTINCTES d'un pool, en servant
  # d'abord les recettes de saison (règle « priorité saison », UC1) :
  # 1. Piocher dans le sous-pool de saison du mois courant.
  # 2. Compléter avec le reste du pool si le quota n'est pas atteint.
  #
  # Peut donc retourner MOINS de recettes que demandé : le pool est ce qu'il
  # est. C'est l'appelant qui décide si un tirage incomplet est une erreur
  # (remplacement d'un repas — CandidatePickerService) ou une simple
  # information (génération par quotas, UC7 — Menu#missing_meal_counts).
  #
  # Le tri aléatoire et la limite sont délégués à PostgreSQL. Le scope
  # seasonal_for_month impose DISTINCT (JOIN ingrédients) : on l'isole en
  # sous-requête pour éviter le conflit PostgreSQL DISTINCT + ORDER BY RANDOM().
  class SeasonalDrawService
    # @param pool [ActiveRecord::Relation<Recipe>] recettes éligibles au tirage
    # @param count [Integer] nombre de recettes souhaité
    # @param excluded_ids [Array<Integer>] recettes à écarter du tirage
    # @return [Array<Recipe>] au plus `count` recettes, celles de saison d'abord
    def self.call(pool:, count:, excluded_ids: [])
      new(pool: pool, count: count, excluded_ids: excluded_ids).call
    end

    def initialize(pool:, count:, excluded_ids:)
      @pool         = pool
      @count        = count
      @excluded_ids = excluded_ids
    end

    def call
      seasonal = draw(Recipe.where(id: seasonal_scope.select(:id)), @count)
      seasonal + draw(offseason_pool, @count - seasonal.size)
    end

    private

    # Tirage SQL : au plus `count` lignes distinctes, ordre aléatoire
    def draw(scope, count)
      return [] unless count.positive?

      scope.where.not(id: @excluded_ids)
           .order(Arel.sql("RANDOM()"))
           .limit(count)
           .to_a
    end

    # Sous-pool de saison : recettes du pool avec ≥ 1 ingrédient de saison ce mois-ci
    def seasonal_scope
      @seasonal_scope ||= @pool.seasonal_for_month(Date.current.month)
    end

    # Le pool moins TOUTES les recettes de saison — déjà servies en priorité,
    # elles ne concourent pas une seconde fois au tour de complément.
    def offseason_pool
      @pool.where.not(id: seasonal_scope.select(:id))
    end
  end
end
