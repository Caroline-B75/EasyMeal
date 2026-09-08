# frozen_string_literal: true

# Comment un ingrédient se compte quand on l'achète.
#
# Le catalogue mesure ce qu'une recette consomme — 600 g d'aubergine, 3 ml de
# lait. Un magasin, lui, vend deux aubergines et une brique. Cet objet-valeur
# porte cette seconde façon de dire, et rien d'autre : combien de pièces, et
# comment elles s'appellent.
#
# Il se construit depuis n'importe quel porteur des quatre attributs — un
# Ingredient ou une ligne de courses, qui les recopie (cf. HasPieceUnit) — et
# rend nil quand l'ingrédient n'a pas de nom de pièce. Ce nom est à la fois
# l'information et l'interrupteur : le poireau et le chocolat pèsent tous deux
# 200 g la pièce et se comptent à l'opposé, aucun seuil ne saurait les séparer.
#
# Deux façons de compter, selon ce que la quantité stockée veut dire :
#
# - l'ingrédient se pèse ou se verse (mass, volume) : la quantité est une mesure,
#   le nombre de pièces s'en déduit — 750 g ÷ 250 g = 3 courgettes ;
# - l'ingrédient se compte (count) : la quantité EST le nombre de pièces, et
#   c'est la mesure qui s'en déduit — 4 pots × 125 g = 500 g.
#
# Reste à savoir si l'on arrondit, car compter est ici deux gestes distincts :
#
# - faire ses courses (par défaut) : on arrondit au supérieur, on n'achète pas
#   deux courgettes et demie. Le décalage que cet arrondi crée n'est jamais tu —
#   c'est lui que `exact?` signale, pour que l'affichage écrive « 3 pièces pour
#   750 g » plutôt que « 3 pièces (750 g) », qui ferait croire à une équivalence ;
# - dire ce qu'une recette consomme (`round_up: false`) : un demi-concombre se
#   coupe, et l'annoncer entier ferait rater le plat. La quantité s'écrit alors
#   telle qu'elle est, au dixième de pièce près.
#
# Ce second geste ne concerne que ce qui se compte, là où la quantité EST un
# nombre de pièces. Sur ce qui se pèse, le nombre de pièces reste déduit d'une
# mesure, et l'arrondi au supérieur demeure la seule façon honnête de le dire :
# « 3,33 blancs de poulet » n'existe dans aucun frigo, « 4 blancs pour 500 g » si.
class PieceUnit
  # Les quantités de base vivent au millième (cf. UnitConversionService) : deux
  # nombres qui ne diffèrent qu'au-delà sont le même nombre, et un ratio de
  # 2,9999999 est un compte juste de 3 pièces déguisé par le flottant.
  PRECISION = 3

  # Une fraction de pièce se lit au dixième — un demi-concombre, un tiers de
  # courgette. Au-delà, le chiffre cesse d'aider à cuisiner.
  COUNT_DECIMALS = 1

  # Ce qui relie les deux nombres quand on achète plus que nécessaire :
  # « 1 brique pour 3 ml ». Les parenthèses, elles, sont réservées à
  # l'équivalence exacte — « 1 brique (1 L) ». Sans cette distinction, une ligne
  # affirmerait qu'il faut une brique entière là où trois gouttes suffisent.
  SURPLUS_CONNECTOR = "pour"

  attr_reader :label, :plural, :measure, :measure_unit_group

  # Le porteur a-t-il de quoi se compter en pièces ? Rend nil sinon — sans nom
  # de pièce, l'ingrédient se pèse, et c'est le cas de la majorité du catalogue.
  #
  # @param record [#piece_label, #piece_label_plural, #piece_measure, #unit_group]
  # @return [PieceUnit, nil]
  def self.for(record)
    label = record.piece_label.presence
    return nil if label.nil?

    measure, measure_unit_group = record.piece_measure

    new(label:      label,
        plural:     record.piece_label_plural.presence,
        measure:    measure,
        measure_unit_group: measure_unit_group,
        unit_group: record.unit_group)
  end

  def initialize(label:, plural: nil, measure: nil, measure_unit_group: nil, unit_group: nil)
    @label              = label
    @plural             = plural
    @measure            = measure
    @measure_unit_group = measure_unit_group
    @unit_group         = unit_group.to_s
  end

  # Nombre de pièces pour cette quantité — à acheter, donc arrondi au supérieur,
  # ou tel que la recette le demande quand `round_up` est faux.
  # nil quand rien ne permet de compter — un ingrédient au poids sans poids de
  # pièce ne se compte pas, et mieux vaut ne rien afficher que deviner.
  #
  # @param quantity [Numeric] quantité en unité de base du porteur
  # @param round_up [Boolean] false pour dire la quantité telle qu'elle est
  # @return [Numeric, nil] un entier à l'achat, au dixième de pièce sinon
  def count_for(quantity, round_up: true)
    pieces = exact_count_for(quantity)
    return nil if pieces.nil?
    return pieces.round(COUNT_DECIMALS) if fractional_pieces?(round_up)

    pieces.round(PRECISION).ceil
  end

  # La quantité tombe-t-elle sur un nombre entier de pièces ? C'est ce qui
  # sépare « 2 pièces (600 g) » — l'équivalence — de « 3 pièces pour 750 g »,
  # où l'on achète plus que nécessaire.
  #
  # Sans arrondi au supérieur, il n'y a par construction aucun surplus à
  # signaler : « 0,5 pièce (200 g) » dit deux fois la même chose, et le dixième
  # de pièce auquel l'affichage se limite ne rend pas la ligne moins vraie.
  #
  # @param quantity [Numeric]
  # @param round_up [Boolean]
  # @return [Boolean]
  def exact?(quantity, round_up: true)
    pieces = exact_count_for(quantity)
    return false if pieces.nil?
    return true if fractional_pieces?(round_up)

    rounded = pieces.round(PRECISION)
    rounded == rounded.to_i
  end

  # La mesure correspondant à cette quantité — ce que la recette consomme
  # vraiment —, prête pour Quantities::HumanizeService :
  # { quantity:, unit_group: }. nil quand on ne sait pas la dire.
  #
  # Pour ce qui se pèse ou se verse, c'est la quantité elle-même. Pour ce qui se
  # compte, c'est ce que pèsent (ou contiennent) ces pièces — l'information
  # qu'on ajoute justement en second : « 4 pots pour 500 g ».
  #
  # @param quantity [Numeric]
  # @return [Hash, nil]
  def measure_for(quantity)
    return nil if measure.nil?
    return { quantity: quantity.to_f, unit_group: @unit_group } unless counted?

    { quantity: quantity.to_f * measure, unit_group: measure_unit_group }
  end

  # Ce qu'il y a à écrire pour cette quantité, en morceaux — le nombre de pièces,
  # leur nom accordé, la mesure déjà humanisée, et si les deux s'équivalent.
  # Rendu en pièces détachées pour que la vue puisse mettre en valeur ce qu'elle
  # veut (le « pour » en gras) sans que le HTML descende jusqu'ici.
  #
  # nil quand il n'y a rien à compter : ni nom de pièce utilisable, ni quantité —
  # y compris une quantité si petite qu'elle ne fait pas un dixième de pièce, que
  # l'appelant dira mieux en la mesurant (« 30 g » plutôt que « 0 pièce »).
  #
  # @param quantity [Numeric] quantité en unité de base du porteur
  # @param round_up [Boolean] false pour dire la quantité telle qu'elle est
  # @return [Hash, nil] { count:, label:, measure:, exact: }
  def describe(quantity, round_up: true)
    count = count_for(quantity, round_up: round_up)
    return nil if count.nil? || count.zero?

    measure = measure_for(quantity)

    {
      count:   display_count(count),
      label:   label_for(count),
      measure: measure && Quantities::HumanizeService.call(**measure)[:display],
      exact:   exact?(quantity, round_up: round_up)
    }
  end

  # La même chose écrite d'un trait, sans mise en forme.
  #
  #   sentence_for(600) → « 2 pièces (600 g) »   la quantité tombe juste
  #   sentence_for(750) → « 3 pièces pour 750 g » on achète plus que nécessaire
  #   sentence_for(0.5, round_up: false) → « 0,5 pièce (200 g) »  ce qu'on cuisine
  #
  # @param quantity [Numeric]
  # @param round_up [Boolean] false pour dire la quantité telle qu'elle est
  # @return [String, nil]
  def sentence_for(quantity, round_up: true)
    parts = describe(quantity, round_up: round_up)
    return nil if parts.nil?

    pieces = "#{parts[:count]} #{parts[:label]}"
    return pieces if parts[:measure].blank?

    parts[:exact] ? "#{pieces} (#{parts[:measure]})" : "#{pieces} #{SURPLUS_CONNECTOR} #{parts[:measure]}"
  end

  # Le nom de la pièce, accordé. Le pluriel n'est écrit en base que là où le
  # français refuse le « s » — maquereaux, gambas et noix invariables ; partout
  # ailleurs la règle régulière suffit et la colonne reste nulle.
  #
  # Le pluriel ne commence qu'à deux, comme en français : « 0,5 pièce »,
  # « 1,8 pièce », puis « 2 pièces ».
  #
  # @param count [Numeric]
  # @return [String]
  def label_for(count)
    return label if count.to_f.abs < 2

    plural || "#{label}s"
  end

  private

  # L'ingrédient se compte-t-il déjà (« 4 yaourts »), ou se mesure-t-il
  # (« 600 g d'aubergine ») ? C'est ce que dit son groupe d'unités, et c'est tout
  # ce qui sépare les deux façons de compter.
  def counted?
    @unit_group == "count"
  end

  # Une fraction de pièce s'écrit-elle ? Seulement sur ce qui se compte, et
  # seulement hors des courses (cf. l'en-tête de la classe).
  def fractional_pieces?(round_up)
    !round_up && counted?
  end

  # Le compte, écrit à la française et sans décimale inutile : « 3 », « 0,5 ».
  def display_count(count)
    ActiveSupport::NumberHelper.number_to_rounded(
      count, precision: COUNT_DECIMALS, strip_insignificant_zeros: true, separator: ","
    )
  end

  # Le nombre de pièces AVANT arrondi — la valeur dont dépendent le compte et
  # son exactitude, calculée une seule fois ici pour que les deux ne puissent
  # pas diverger.
  def exact_count_for(quantity)
    return quantity.to_f if counted?
    return nil if measure.nil? || measure.zero?

    quantity.to_f / measure
  end
end
