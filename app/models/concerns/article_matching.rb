# frozen_string_literal: true

# « Cet article est-il déjà là ? » — la question que posent la liste de courses
# (ajout manuel, ajout des habituels) et la liste des courses habituelles (un
# article n'y figure qu'une fois).
#
# Deux articles sont le même quand ils partagent leur ingrédient, ou, à défaut
# d'ingrédient, leur nom — aux accents et à la casse près, la liste affichant
# « Œufs » là où on saisit « oeufs ».
#
# Le modèle qui l'inclut porte une colonne `name` et une association `ingredient`.
module ArticleMatching
  extend ActiveSupport::Concern

  included do
    # @param name [String]
    # @param ingredient [Ingredient, nil]
    scope :matching_article, ->(name:, ingredient: nil) {
      by_name = where("unaccent(LOWER(name)) = unaccent(LOWER(:name))", name: name.to_s.strip)
      ingredient ? by_name.or(where(ingredient: ingredient)) : by_name
    }
  end
end
