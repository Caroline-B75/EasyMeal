# frozen_string_literal: true

module Menus
  # Levée quand aucune recette candidate n'est disponible pour un ajout ou remplacement.
  # Les pools saison ET hors saison sont tous épuisés (recettes déjà toutes présentes).
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
