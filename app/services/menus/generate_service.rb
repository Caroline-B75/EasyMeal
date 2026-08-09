# frozen_string_literal: true

module Menus
  # Génère un Menu(status: :draft) persisté en base avec ses repas initiaux.
  #
  # Appelé depuis MenusController#create lors de la soumission du formulaire
  # de génération (UC1/UC7).
  #
  # Le remplissage relève de ComposeMealsService — partagé avec la
  # re-génération d'un brouillon : un pool par moment commandé, priorité
  # saison à l'intérieur de chaque quota, remplissage partiel sans erreur
  # (les pools trop maigres deviennent des manques affichés, jamais un échec).
  #
  # @example
  #   menu = Menus::GenerateService.call(
  #     user: current_user,
  #     diet: :vegetarien,
  #     default_people: 4,
  #     meal_counts: MealCounts.from_hash({ "breakfast" => 7, "dinner" => 7 })
  #   )
  #   # => Menu (status: :draft, persisted)
  class GenerateService
    # @param user [User]
    # @param diet [Symbol, String] Régime alimentaire (ex: :vegetarien)
    # @param default_people [Integer] Nombre de personnes par défaut pour les repas
    # @param meal_counts [MealCounts] Répartition des repas commandée, par moment
    # @param name [String, nil] Nom du menu (auto-généré si absent)
    # @return [Menu] Menu draft persisté
    def self.call(user:, diet:, default_people:, meal_counts:, name: nil)
      new(
        user: user,
        diet: diet,
        default_people: default_people,
        meal_counts: meal_counts,
        name: name
      ).call
    end

    def initialize(user:, diet:, default_people:, meal_counts:, name:)
      @user           = user
      @diet           = diet.to_s
      @default_people = default_people.to_i
      @meal_counts    = meal_counts
      @name           = name.presence || Menu.default_name
    end

    # Un seul brouillon par utilisateur : l'éventuel brouillon précédent est
    # remplacé dans la même transaction que la création du nouveau.
    def call
      ActiveRecord::Base.transaction do
        @user.menus.status_draft.find_each(&:destroy!)

        menu = Menu.create!(
          user:           @user,
          name:           @name,
          diet:           @diet,
          default_people: @default_people,
          status:         :draft
        )

        ComposeMealsService.call(menu: menu, meal_counts: @meal_counts)
      end
    end
  end
end
