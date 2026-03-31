# frozen_string_literal: true

module Menus
  # Génère un Menu(status: :draft) persisté en base avec ses repas initiaux.
  #
  # Appelé depuis MenusController#create lors de la soumission du formulaire
  # de génération (UC1).
  #
  # Algorithme de sélection (UC1 — règle "priorité saison") :
  # 1. Construire le pool de saison (recettes compatibles + de saison ce mois).
  # 2. Mélanger aléatoirement ce pool et piocher jusqu'à number_of_meals.
  # 3. Compléter avec le pool hors saison si le pool saison est insuffisant.
  # 4. Créer le Menu et les MenuRecipes dans une transaction atomique.
  #
  # @example
  #   menu = Menus::GenerateService.call(
  #     user: current_user,
  #     diet: :vegetarien,
  #     default_people: 4,
  #     number_of_meals: 6
  #   )
  #   # => Menu (status: :draft, persisted)
  class GenerateService
    # @param user [User]
    # @param diet [Symbol, String] Régime alimentaire (ex: :vegetarien)
    # @param default_people [Integer] Nombre de personnes par défaut pour les repas
    # @param number_of_meals [Integer] Nombre de repas à générer
    # @param name [String, nil] Nom du menu (auto-généré si absent)
    # @return [Menu] Menu draft persisté
    def self.call(user:, diet:, default_people:, number_of_meals:, name: nil)
      new(
        user: user,
        diet: diet,
        default_people: default_people,
        number_of_meals: number_of_meals,
        name: name
      ).call
    end

    def initialize(user:, diet:, default_people:, number_of_meals:, name:)
      @user           = user
      @diet           = diet.to_s
      @default_people = default_people.to_i
      @number_of_meals = number_of_meals.to_i
      @name           = name.presence || auto_name
    end

    def call
      selection = pick_recipes
      build_menu(selection)
    end

    private

    # Sélectionne number_of_meals recettes sans doublons (saison d'abord)
    def pick_recipes
      month    = Date.current.month
      seasonal = Recipe.compatible_with(@diet).seasonal_for_month(month).to_a.shuffle
      other    = Recipe.compatible_with(@diet)
                       .where.not(id: seasonal.map(&:id))
                       .to_a.shuffle

      # Priorité saison, compléter hors saison si besoin
      selection = (seasonal + other).first(@number_of_meals)

      # Si le catalogue est vraiment vide pour ce régime
      raise Menus::NoCandidatesError if selection.empty?

      selection
    end

    # Crée le Menu et ses MenuRecipes dans une transaction atomique
    def build_menu(selection)
      ActiveRecord::Base.transaction do
        menu = Menu.create!(
          user:           @user,
          name:           @name,
          diet:           @diet,
          default_people: @default_people,
          status:         :draft
        )

        selection.each_with_index do |recipe, index|
          menu.menu_recipes.create!(
            recipe:           recipe,
            number_of_people: @default_people,
            position:         index
          )
        end

        menu
      end
    end

    # Nom par défaut si aucun nom n'est fourni par l'utilisateur
    def auto_name
      "Menu du #{Date.current.strftime('%d/%m/%Y')}"
    end
  end
end
