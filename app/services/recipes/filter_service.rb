# frozen_string_literal: true

module Recipes
  # Applique les filtres de recherche sur un scope de recettes
  # Chaque filtre est optionnel et n'est activé que si le paramètre est présent
  #
  # @example
  #   Recipes::FilterService.call(Recipe.all, params)
  #   # => ActiveRecord::Relation filtrée
  #
  class FilterService
    # Table de dispatch : associe chaque clé de paramètre à la méthode de scope correspondante.
    # Chaque param n'est lu qu'une seule fois, éliminant les appels dupliqués.
    PARAM_FILTERS = [
      [ :query,               ->(scope, val) { scope.search(val) } ],
      [ :diet,                ->(scope, val) { scope.for_diet(val) } ],
      [ :difficulty,          ->(scope, val) { scope.by_difficulty(val) } ],
      [ :max_time,            ->(scope, val) { scope.with_total_time_lte(val) } ],
      [ :include_ingredients, ->(scope, val) { scope.with_ingredient_names(val) } ],
      [ :exclude_ingredients, ->(scope, val) { scope.without_ingredient_names(val) } ]
    ].freeze

    def self.call(scope, params)
      new(scope, params).call
    end

    def initialize(scope, params)
      @scope = scope
      @params = params
    end

    def call
      scope = apply_param_filters(@scope)
      apply_seasonal_filter(scope)
    end

    private

    # Applique en séquence tous les filtres de PARAM_FILTERS si leur param est présent
    def apply_param_filters(scope)
      PARAM_FILTERS.reduce(scope) do |current_scope, (param_key, filter_fn)|
        value = @params[param_key]
        value.present? ? filter_fn.call(current_scope, value) : current_scope
      end
    end

    # Filtre saisonnier : condition spéciale (== "true" et non .present?)
    def apply_seasonal_filter(scope)
      @params[:seasonal] == "true" ? scope.seasonal_for_month(Date.current.month) : scope
    end
  end
end
