# frozen_string_literal: true

module Recipes
  # Assemble le catalogue affiché par RecipesController#index (UC5) : la page de
  # recettes filtrée et triée, plus tout ce que la vue doit connaître autour
  # d'elle (tags de la sidebar, favoris de l'utilisateur, recettes de saison).
  #
  # Le filtrage lui-même reste chez FilterService ; ce que cet objet apporte,
  # c'est le préchargement en UNE requête de chaque donnée transverse aux cartes
  # — jamais une requête par carte (cf. les Set ci-dessous).
  #
  # La pagination, elle, ne peut pas descendre ici : Pagy est un helper de
  # contrôleur. Elle est donc injectée sous forme de bloc qui reçoit la relation
  # filtrée et renvoie le couple [pagy, recettes de la page].
  #
  # @example
  #   catalog = Recipes::CatalogQuery.call(scope: policy_scope(Recipe),
  #                                        params: params,
  #                                        user: current_user) { |rel| pagy(rel, items: 20) }
  #   catalog.recipes            # => [Recipe] (page courante)
  #   catalog.seasonal?(recipe)  # => true / false, sans requête
  class CatalogQuery
    # Associations nécessaires au rendu d'une carte (tags, note moyenne, photo).
    CARD_INCLUDES = [ :tags, :reviews, :photo_attachment ].freeze

    # Tri par défaut du catalogue quand aucun ?sort= n'est demandé.
    DEFAULT_SORT = :name

    # La liste des tags de la sidebar est identique pour tout le monde et bouge
    # rarement : elle est mutualisée en cache plutôt que rejouée à chaque page.
    TAGS_CACHE_KEY = "tags/with_recipes"
    TAGS_CACHE_TTL = 1.hour

    # Catalogue prêt à afficher. Les appartenances sont exposées en prédicats :
    # la vue interroge carte par carte sans rien savoir des Set préchargés.
    Catalog = Data.define(:pagy, :recipes, :tags, :favorited_ids, :seasonal_ids, :current_month) do
      def favorited?(recipe) = favorited_ids.include?(recipe.id)
      def seasonal?(recipe)  = seasonal_ids.include?(recipe.id)
    end

    # @param scope [ActiveRecord::Relation] scope de base (autorisé, éventuellement restreint aux favoris)
    # @param params [ActionController::Parameters] params de la requête (filtres + tri)
    # @param user [User, nil] utilisateur connecté, pour l'état des coeurs favoris
    # @yieldparam relation [ActiveRecord::Relation] relation filtrée à paginer
    # @yieldreturn [Array(Pagy, ActiveRecord::Relation)] couple renvoyé par Pagy
    # @return [Catalog]
    def self.call(scope:, params:, user:, &paginator)
      new(scope: scope, params: params, user: user, paginator: paginator).call
    end

    def initialize(scope:, params:, user:, paginator:)
      @scope     = scope
      @params    = params
      @user      = user
      @paginator = paginator
    end

    def call
      pagy, page = @paginator.call(filtered_scope)
      # Chargement forcé une bonne fois : la page est ensuite parcourue
      # plusieurs fois (IDs des favoris, puis de saison, puis rendu des cartes).
      recipes = page.to_a

      Catalog.new(
        pagy:          pagy,
        recipes:       recipes,
        tags:          tags,
        favorited_ids: favorited_ids(recipes),
        seasonal_ids:  seasonal_ids(recipes),
        current_month: current_month
      )
    end

    private

    # Relation filtrée, préchargée et triée — celle que le bloc paginera
    def filtered_scope
      FilterService.call(@scope, @params)
                   .includes(*CARD_INCLUDES)
                   .order(@params[:sort] || DEFAULT_SORT)
    end

    def tags
      Rails.cache.fetch(TAGS_CACHE_KEY, expires_in: TAGS_CACHE_TTL) do
        Tag.joins(:recipes).distinct.alphabetical.to_a
      end
    end

    # Coeurs favoris de la page en une requête, plutôt qu'un favorited_by? par carte
    def favorited_ids(recipes)
      return Set.new unless @user

      Set.new(FavoriteRecipe.where(user: @user, recipe_id: recipes.map(&:id)).pluck(:recipe_id))
    end

    # Badge « De saison » sur les cartes : on précalcule en UNE requête les IDs
    # de recettes de saison ce mois-ci, plutôt que d'appeler seasonal_for_month?
    # par carte (les ingrédients ne sont pas eager-loaded → éviterait un N+1).
    def seasonal_ids(recipes)
      return Set.new if recipes.empty?

      Set.new(Recipe.seasonal_for_month(current_month).where(id: recipes.map(&:id)).pluck(:id))
    end

    # Mois de référence des badges de saison — également repris dans la clé de
    # cache des cartes, qui doit s'invalider au changement de mois.
    def current_month
      @current_month ||= Date.current.month
    end
  end
end
