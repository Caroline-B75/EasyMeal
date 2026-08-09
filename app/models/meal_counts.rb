# frozen_string_literal: true

# Répartition des repas d'une semaine, moment par moment (UC7, chapitre 2).
#
# Objet-valeur qui encapsule le petit hash { "breakfast" => 7, "dinner" => 7 } :
# saisi dans le formulaire de génération, mémorisé en jsonb — semaine type de
# l'utilisatrice (User#default_meal_counts) comme commande d'un menu
# (Menu#requested_meal_counts) — et honoré par le moteur de génération.
#
# Il porte aussi l'option « même petit-déjeuner toute la semaine » : ce n'est pas
# un réglage indépendant mais une facette de la commande passée, elle voyage donc
# avec la répartition plutôt que dans un coin séparé.
#
# Trois garanties, quelle que soit la provenance des données (formulaire, jsonb,
# menu déjà composé) :
# - seuls les moments du vocabulaire MealTypes::MEAL_TYPES sont retenus ;
# - chaque quota est un entier borné à [MIN, MAX] ;
# - les quotas nuls sont absents — un moment non commandé n'existe pas.
class MealCounts
  # Bornes d'un stepper : deux semaines de marge suffisent largement, et un
  # quota négatif n'a pas de sens.
  MIN = 0
  MAX = 14

  # Moment concerné par l'option de répétition.
  BREAKFAST = "breakfast"

  # Clé réservée du hash stocké. Elle cohabite sans risque avec les moments :
  # ce n'est pas un MealTypes::MEAL_TYPES, la normalisation l'ignore donc.
  SAME_BREAKFAST_KEY = "same_breakfast"

  # Répéter un petit-déjeuner n'a de sens qu'à partir de deux matins.
  SAME_BREAKFAST_MIN = 2

  # Moment d'accueil des repas encore sans moment (menus générés avant le
  # moteur par quotas). Les recettes existantes ayant été backfillées en
  # « déjeuner + dîner », le déjeuner est le choix neutre. Il préserve le
  # total d'une composition, qu'on la compare à une commande
  # (Menu#missing_meal_counts) ou qu'elle pré-remplisse le formulaire de
  # re-génération d'un vieux brouillon.
  UNTYPED_MEAL_TYPE = "lunch"

  # Construit une répartition depuis n'importe quelle source clé → valeur :
  # params de formulaire (ActionController::Parameters), colonne jsonb ou hash.
  # Les params ne sont volontairement pas « permit »és en amont : la liste
  # blanche, c'est la normalisation ci-dessous.
  # @param source [Hash, ActionController::Parameters, nil]
  # @return [MealCounts]
  def self.from_hash(source)
    hash = (source.respond_to?(:to_unsafe_h) ? source.to_unsafe_h : source.to_h).stringify_keys

    new(hash, same_breakfast: ActiveModel::Type::Boolean.new.cast(hash[SAME_BREAKFAST_KEY]))
  end

  # Répartition d'un menu déjà composé : ses repas, comptés par moment.
  # Prend la collection plutôt que le menu, pour réutiliser celle que la vue a
  # déjà chargée au lieu de relancer un GROUP BY. Le rangement des repas sans
  # moment est celui de MenuRecipe#display_meal_type — une seule règle.
  # @param menu_recipes [Enumerable<MenuRecipe>]
  # @return [MealCounts]
  def self.from_menu_recipes(menu_recipes)
    new(menu_recipes.map(&:display_meal_type).tally)
  end

  # @param counts [Hash] quotas bruts, clés string ou symbol
  # @param same_breakfast [Boolean] option « même petit-déjeuner toute la semaine »
  def initialize(counts = {}, same_breakfast: false)
    @counts         = normalize(counts)
    @same_breakfast = same_breakfast
  end

  # Quota commandé pour un moment — 0 s'il n'est pas au menu.
  # @param meal_type [String, Symbol]
  # @return [Integer]
  def [](meal_type)
    @counts.fetch(meal_type.to_s, 0)
  end

  # Nombre total de repas commandés.
  def total
    @counts.values.sum
  end

  # Y a-t-il de quoi générer ? C'est la règle « au moins 1 repas ».
  def any?
    total.positive?
  end

  # Cochée avec 0 ou 1 petit-déjeuner, l'option ne veut rien dire : on ne la
  # mémorise pas et on ne la transmet pas.
  def same_breakfast?
    @same_breakfast && self[BREAKFAST] >= SAME_BREAKFAST_MIN
  end

  # Forme stockable en jsonb, rejouable telle quelle par le formulaire.
  # @return [Hash]
  def to_h
    same_breakfast? ? @counts.merge(SAME_BREAKFAST_KEY => true) : @counts.dup
  end

  # Même répartition, un seul moment porté à un nouveau quota — le geste d'un
  # stepper, qui ne touche jamais qu'un moment à la fois. L'objet-valeur reste
  # immuable : une nouvelle instance est renvoyée, normalisée comme les autres.
  # @param meal_type [String, Symbol]
  # @param count [Integer]
  # @return [MealCounts]
  def with(meal_type, count)
    self.class.from_hash(to_h.merge(meal_type.to_s => count))
  end

  private

  # Ne garde que les moments connus, en entiers bornés, sans les zéros.
  def normalize(counts)
    source = counts.to_h.stringify_keys

    MealTypes::MEAL_TYPES.each_with_object({}) do |meal_type, normalized|
      quantity = source[meal_type].to_i.clamp(MIN, MAX)
      normalized[meal_type] = quantity if quantity.positive?
    end
  end
end
