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
    def self.call(scope, params)
      new(scope, params).call
    end

    def initialize(scope, params)
      @scope = scope
      @params = params
    end

    def call
      @scope
        .then { |r| @params[:query].present?               ? r.search(@params[:query]) : r }
        .then { |r| @params[:diet].present?                ? r.for_diet(@params[:diet]) : r }
        .then { |r| @params[:difficulty].present?          ? r.by_difficulty(@params[:difficulty]) : r }
        .then { |r| @params[:seasonal] == "true"           ? r.seasonal_for_month(Date.current.month) : r }
        .then { |r| @params[:max_time].present?            ? r.with_total_time_lte(@params[:max_time]) : r }
        .then { |r| @params[:include_ingredients].present? ? r.with_ingredient_names(@params[:include_ingredients]) : r }
        .then { |r| @params[:exclude_ingredients].present? ? r.without_ingredient_names(@params[:exclude_ingredients]) : r }
    end
  end
end
