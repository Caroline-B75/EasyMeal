# frozen_string_literal: true

module Menus
  # Ajuste d'un cran le nombre de repas d'UN moment dans un brouillon (UC7) —
  # le geste des steppers de répartition du panneau de réglages.
  #
  # - « + » tire une recette du moment (CandidatePickerService : priorité
  #   saison, jamais un doublon de ce moment) et la pose à la suite de la
  #   grille, là où atterrit tout ajout ;
  # - « − » retire le dernier repas du moment dans la grille — celui qu'un
  #   ajout vient d'y poser.
  #
  # La commande du menu suit ensuite l'intention exprimée : le moment ajusté
  # voit son quota aligné sur ce que la grille contient désormais. Sans cela,
  # retirer un dîner ferait aussitôt apparaître « Il manque 1 dîner » alors
  # qu'on vient de le retirer exprès. Les autres moments ne bougent pas.
  #
  # Contrairement à la génération, où un pool trop maigre n'est jamais une
  # erreur, l'ajout est ici un geste explicite : il lève
  # Menus::NoCandidatesError plutôt que de ne rien faire en silence.
  class AdjustMealCountService
    # Le pool du moment est épuisé. Message propre à ce geste : celui du
    # remplacement 🔀 ne nommerait pas le moment concerné.
    NO_CANDIDATES = "Plus aucune nouvelle recette de %{meal} disponible pour ce menu."

    # @param menu [Menu] brouillon à ajuster
    # @param meal_type [String] moment concerné (MealTypes::MEAL_TYPES)
    # @param delta [Integer] +1 pour ajouter un repas, −1 pour en retirer un
    # @return [Menu] le menu ajusté
    # @raise [Menus::NoCandidatesError]
    def self.call(menu:, meal_type:, delta:)
      new(menu: menu, meal_type: meal_type, delta: delta).call
    end

    def initialize(menu:, meal_type:, delta:)
      @menu      = menu
      @meal_type = meal_type
      @delta     = delta
    end

    def call
      ActiveRecord::Base.transaction do
        add_meal      if @delta.positive?
        remove_meal   if @delta.negative?
        realign_command!
      end

      @menu
    end

    private

    # Les repas de ce moment, tels que la grille et les steppers les comptent
    # (les repas sans moment sont rangés au déjeuner). Relation reconstruite à
    # chaque appel : elle doit refléter la composition d'après la mutation.
    def meals
      @menu.menu_recipes.displayed_as(@meal_type)
    end

    # Garde-fou serveur au plafond des quotas : le « + » y est déjà désactivé.
    def add_meal
      return if meals.count >= MealCounts::MAX

      @menu.append_meal!(recipe: recipe_to_add, meal_type: @meal_type)
    end

    # « Même petit-déjeuner toute la semaine » oblige : un matin de plus, c'est
    # la même brioche — sinon on tire un candidat du moment.
    def recipe_to_add
      repeated_breakfast || draw_candidate
    end

    def repeated_breakfast
      return nil unless @meal_type == MealCounts::BREAKFAST && @menu.requested_counts.same_breakfast?

      meals.by_position.first&.recipe
    end

    def draw_candidate
      CandidatePickerService.call(menu: @menu, meal_type: @meal_type)
    rescue Menus::NoCandidatesError
      raise Menus::NoCandidatesError,
            format(NO_CANDIDATES, meal: MealTypes.inline_label(@meal_type, 1))
    end

    # Rien à retirer si le moment est déjà vide : le « − » y est désactivé.
    def remove_meal
      meals.by_position.last&.destroy!
    end

    # Le quota du moment ajusté rejoint ce que la grille contient : c'est
    # l'utilisatrice qui vient de dire combien elle en veut.
    def realign_command!
      @menu.update!(requested_meal_counts: @menu.requested_counts.with(@meal_type, meals.count).to_h)
    end
  end
end
