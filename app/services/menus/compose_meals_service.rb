# frozen_string_literal: true

module Menus
  # Compose les repas d'un menu pour honorer une commande MealCounts (UC7, ch. 3).
  # C'est le moteur commun de la génération (menu tout juste créé) et de la
  # re-génération (brouillon existant dont on change les paramètres) : toute
  # composition antérieure du menu est remplacée.
  #
  # Pour chaque moment commandé, dans l'ordre de la journée :
  # - pool = recettes publiées, compatibles avec le régime ET taguées du moment ;
  # - priorité saison À L'INTÉRIEUR du quota (SeasonalDrawService) ;
  # - jamais deux fois la même recette dans un même moment — mais elle peut
  #   réapparaître dans un autre (une quiche au déjeuner ET au dîner) ;
  # - option « même petit-déjeuner toute la semaine » : UNE recette tirée,
  #   placée N fois (N cartes distinctes) ;
  # - un pool trop maigre n'est JAMAIS une erreur : on place ce qu'on peut,
  #   Menu#missing_meal_counts expose le manque, affiché dans le brouillon.
  #
  # La commande est mémorisée sur le menu (requested_meal_counts) : c'est elle
  # qui alimente l'affichage des manques et la re-génération à l'identique.
  class ComposeMealsService
    # @param menu [Menu] menu persisté, régime et personnes à jour
    # @param meal_counts [MealCounts] la commande à honorer
    # @return [Menu] le menu recomposé
    def self.call(menu:, meal_counts:)
      new(menu: menu, meal_counts: meal_counts).call
    end

    def initialize(menu:, meal_counts:)
      @menu        = menu
      @meal_counts = meal_counts
    end

    def call
      picks = plan_picks

      ActiveRecord::Base.transaction do
        @menu.update!(requested_meal_counts: @meal_counts.to_h)
        @menu.menu_recipes.destroy_all

        picks.each_with_index do |(recipe, meal_type), position|
          @menu.menu_recipes.create!(
            recipe:           recipe,
            meal_type:        meal_type,
            position:         position,
            number_of_people: @menu.default_people
          )
        end
      end

      @menu
    end

    private

    # Paires [recette, moment] à créer, dans l'ordre de la journée — les
    # positions suivent, le brouillon se lit donc du petit-déj au dîner.
    def plan_picks
      MealTypes::MEAL_TYPES.flat_map { |meal_type| picks_for(meal_type) }
    end

    def picks_for(meal_type)
      quota = @meal_counts[meal_type]
      return [] if quota.zero?

      recipes = if same_breakfast?(meal_type)
        repeated_breakfast(quota)
      else
        draw(meal_type, quota)
      end

      recipes.map { |recipe| [ recipe, meal_type ] }
    end

    def same_breakfast?(meal_type)
      meal_type == MealCounts::BREAKFAST && @meal_counts.same_breakfast?
    end

    # Une seule brioche, sept matins heureux : la même recette remplit tout le
    # quota. Pool vide → aucun petit-déjeuner, comme pour un tirage classique.
    def repeated_breakfast(quota)
      recipe = draw(MealCounts::BREAKFAST, 1).first
      recipe ? [ recipe ] * quota : []
    end

    # Tirage saison d'abord. Le tirage SQL est distinct par nature : pas de
    # doublon à l'intérieur d'un moment — c'est ENTRE moments que la répétition
    # est permise, chaque quota interrogeant son pool indépendamment.
    def draw(meal_type, count)
      SeasonalDrawService.call(pool: pool_for(meal_type), count: count)
    end

    # Recettes publiées, compatibles avec le régime du menu, taguées du moment
    def pool_for(meal_type)
      Recipe.published.compatible_with(@menu.diet).for_meal_type(meal_type)
    end
  end
end
