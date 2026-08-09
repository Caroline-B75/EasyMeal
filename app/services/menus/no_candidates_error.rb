# frozen_string_literal: true

module Menus
  # Levée quand aucune recette candidate n'est disponible pour le remplacement
  # d'un repas : les pools saison ET hors saison du moment sont épuisés.
  #
  # Usage :
  #   rescue Menus::NoCandidatesError => e
  #     flash.now[:alert] = e.message
  class NoCandidatesError < StandardError
    def initialize(msg = "Plus de recettes disponibles pour ce critère.")
      super
    end
  end
end
