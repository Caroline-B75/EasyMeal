# frozen_string_literal: true

# Vocabulaire partagé des moments du repas (UC7).
#
# Deux modèles s'en servent, avec des cardinalités différentes :
# - Recipe#meal_types    (array)  : une recette peut convenir à PLUSIEURS moments
#                                   — une quiche vit au déjeuner ET au dîner.
# - MenuRecipe#meal_type (string) : un repas planifié occupe UN moment précis.
#
# La liste est ordonnée comme la journée se déroule : c'est cet ordre qui pilote
# l'affichage (chips du formulaire recette, steppers du formulaire de menu).
#
# Les libellés sont exposés sur le module lui-même (MealTypes.label & co) et
# nulle part ailleurs : un seul chemin d'appel, quel que soit l'appelant —
# modèle, helper ou vue.
module MealTypes
  extend ActiveSupport::Concern

  MEAL_TYPES = %w[breakfast lunch snack apero dinner].freeze

  # Libellé français au singulier — « Petit-déjeuner ».
  # @param meal_type [String, Symbol, nil]
  # @return [String, nil] nil si aucun moment n'est fourni
  def self.label(meal_type)
    translate(meal_type, "meal_types")
  end

  # Libellé au pluriel — « Petits-déjeuners ». C'est la forme dans laquelle on
  # commande des repas (« combien en veux-tu ? ») et dont on titre une section.
  # @param meal_type [String, Symbol, nil]
  # @return [String, nil]
  def self.plural_label(meal_type)
    translate(meal_type, "meal_types_plural")
  end

  # Libellé des colonnes étroites — « Petit-déj ». Registre distinct du
  # singulier complet, pour les endroits où « Petit-déjeuner » ne tient pas :
  # les deux sélecteurs qui se partagent la largeur d'une carte de repas, et
  # les steppers de répartition du panneau de réglages du brouillon.
  # @param meal_type [String, Symbol, nil]
  # @return [String, nil]
  def self.compact_label(meal_type)
    translate(meal_type, "meal_types_compact")
  end

  # Libellé court et accordé, pour les résumés compacts — « 7 petits-déjs ».
  # @param meal_type [String, Symbol, nil]
  # @param count [Integer] pilote l'accord singulier / pluriel
  # @return [String, nil]
  def self.short_label(meal_type, count)
    translate(meal_type, "meal_types_short", count: count)
  end

  # Libellé en minuscules et accordé en nombre : la forme qui s'insère au fil
  # d'une phrase — « ajoute-les aux goûters », « il manque 1 apéro ».
  # @param meal_type [String, Symbol, nil]
  # @param count [Integer] pluriel par défaut, registre le plus courant
  # @return [String, nil]
  def self.inline_label(meal_type, count = 2)
    (count == 1 ? label(meal_type) : plural_label(meal_type))&.downcase
  end

  # Noms d'icônes du helper (ApplicationHelper::FEATHER_ICONS). Privé : le seul
  # chemin d'appel est MealTypes.icon, comme pour les libellés.
  ICONS = {
    "breakfast" => "sunrise",
    "lunch"     => "sun",
    "snack"     => "coffee",
    "apero"     => "glass",
    "dinner"    => "moon"
  }.freeze
  private_constant :ICONS

  # Icône d'un moment — le repère visuel qui DOUBLE le libellé là où le moment
  # n'est pas modifiable (étiquette figée d'un menu validé), jamais qui le
  # remplace. Elle appartient au vocabulaire du moment au même titre que ses
  # libellés : elle se nomme ici, et nulle part ailleurs.
  # @param meal_type [String, Symbol, nil]
  # @return [String] nom d'icône à passer à svg_icon — une icône générique si le
  #   moment est inconnu : un libellé décoratif ne doit jamais faire tomber une page
  def self.icon(meal_type)
    ICONS.fetch(meal_type.to_s, "utensils")
  end

  # Traduction commune aux trois registres de libellés ci-dessus.
  def self.translate(meal_type, scope, **options)
    return nil if meal_type.blank?

    I18n.t("#{scope}.#{meal_type}", default: meal_type.to_s.humanize, **options)
  end
  private_class_method :translate
end
