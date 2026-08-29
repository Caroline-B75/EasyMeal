# frozen_string_literal: true

module Recipes
  # Levée par n'importe quelle étape de l'import d'une recette — récupération de
  # la page, lecture de son schema.org, appel à l'IA. Le message est déjà rédigé
  # en français et affichable tel quel à l'utilisatrice.
  #
  # Elle vit au niveau du module, et non dans l'une des classes qui la lèvent :
  # chacune peut ainsi la lever sans rien connaître des autres.
  #
  # Usage :
  #   rescue Recipes::ExtractionError => e
  #     redirect_to new_recipe_import_path, alert: "Extraction échouée : #{e.message}"
  class ExtractionError < StandardError; end
end
