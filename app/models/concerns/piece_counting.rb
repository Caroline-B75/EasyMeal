# frozen_string_literal: true

# Ce qu'il faut porter pour se compter en pièces : un nom de pièce, son pluriel
# quand le « s » ne suffit pas, et ce que contient une pièce — un poids ou un
# volume, jamais les deux.
#
# Deux modèles portent ces quatre attributs : l'ingrédient du catalogue, qui en
# est la source, et la ligne de courses, qui les recopie pour rester lisible
# après le retrait de son ingrédient et pour ne pas payer une jointure par ligne
# (comme elle recopie déjà le nom, le rayon et l'unité). Ce concern est le
# contrat commun, et la seule porte vers PieceUnit — qui, lui, sait compter.
module PieceCounting
  extend ActiveSupport::Concern

  # Colonnes recopiées d'un ingrédient vers sa ligne de courses. Nommées ici
  # plutôt qu'énumérées dans le service de génération : elles vont ensemble, et
  # en oublier une donnerait un libellé sans son coefficient.
  PIECE_ATTRIBUTES = %i[piece_weight_g piece_volume_ml piece_label piece_label_plural].freeze

  included do
    # Poids d'une pièce : il ne se renseigne que là où l'ingrédient se dit dans
    # les deux langues (une aubergine pèse 300 g), et sert alors de pont entre
    # les recettes qui comptent et le catalogue qui pèse.
    validates :piece_weight_g,
              numericality: { greater_than: 0, message: "doit être supérieur à 0" },
              allow_nil: true
    validate :piece_weight_only_for_countable_or_weighable

    # Volume d'une pièce, son jumeau pour ce qui se verse : une brique de lait
    # contient 1 L comme une aubergine pèse 300 g.
    validates :piece_volume_ml,
              numericality: { greater_than: 0, message: "doit être supérieur à 0" },
              allow_nil: true
    validate :piece_volume_only_for_pourable_or_countable
    validate :single_piece_measure

    # Nom de la pièce, et son pluriel quand le « s » ne suffit pas.
    validate :piece_label_needs_a_way_to_count
    validate :piece_label_plural_accompanies_label
  end

  # Ce que contient UNE pièce, et dans quelle langue : [300.0, "mass"] pour une
  # aubergine, [1000.0, "volume"] pour une brique de lait. nil quand rien ne le
  # dit.
  #
  # Les deux ne cohabitent jamais (validation), mais c'est ici — et ici seulement
  # — qu'on choisit lequel lire : l'affichage (PieceUnit) et la conversion
  # (UnitConversionService) posent la même question et doivent recevoir la même
  # réponse. Indépendant du nom de la pièce : « 2 tranches de jambon » se
  # convertit en 80 g même sur un ingrédient qu'on ne compte pas à l'achat.
  #
  # @return [Array(Float, String), nil]
  def piece_measure
    return [ piece_weight_g.to_f, "mass" ] if piece_weight_g.to_f.positive?
    return [ piece_volume_ml.to_f, "volume" ] if piece_volume_ml.to_f.positive?

    nil
  end

  # Comment cet ingrédient se compte à l'achat, nil s'il se pèse.
  # Volontairement non mémoïsé : l'objet est léger, et un cache se périmerait à
  # la première assignation d'attribut.
  # @return [PieceUnit, nil]
  def piece_unit
    PieceUnit.for(self)
  end

  # S'achète-t-il à la pièce ? Raccourci de lecture pour les vues et les
  # sélecteurs d'unité.
  # @return [Boolean]
  def counted_by_piece?
    piece_label.present?
  end

  # Les unités qu'on propose à la saisie pour CET ingrédient, prêtes pour
  # options_for_select : [[libellé, unité canonique]].
  #
  # Units n'en connaît qu'une part — celles du groupe, et celles qu'une
  # équivalence universelle y ramène (la cuillère aux liquides). La pièce, elle,
  # n'a rien d'universel : deux aubergines ne font 600 g que parce que CET
  # ingrédient pèse 300 g la pièce. C'est donc ici, et pas dans le vocabulaire
  # des unités, que les deux façons de dire se rejoignent.
  #
  # Elles se rejoignent dans les deux sens, faute de quoi deux ingrédients
  # voisins d'une même recette se saisiraient différemment sans raison visible :
  #
  # - ce qui se pèse ou se verse gagne sa pièce — « 2 aubergines » ;
  # - ce qui se compte gagne sa mesure — « 200 g d'oignon », que l'import par IA
  #   sait déjà lire.
  #
  # @return [Array<Array(String, String)>]
  def unit_select_options
    own = Units.select_options(unit_group).map do |label, unit|
      # Sur un ingrédient déjà compté, l'unité « pièce » porte son vrai nom.
      unit == Units::DEFAULT_UNIT && counted_by_piece? ? [ piece_label, unit ] : [ label, unit ]
    end

    own + piece_bridge_options
  end

  private

  # Ce que le coefficient de pièce ajoute au sélecteur, et rien de plus : la
  # pièce pour ce qui se mesure, la mesure pour ce qui se compte. Vide quand
  # l'ingrédient ne s'achète pas à la pièce.
  def piece_bridge_options
    return [] unless counted_by_piece?
    return [ [ piece_label, Units::DEFAULT_UNIT ] ] unless unit_group_count?

    measure_group = piece_unit&.measure_unit_group
    measure_group ? Units.select_options(measure_group) : []
  end

  # Le poids d'une pièce ne relie que la masse et le compte. Sur un ingrédient
  # en ml ou en cuillères, il n'aurait aucun sens à la conversion — mieux vaut
  # le refuser à la saisie que le laisser dormir dans la base sans effet.
  def piece_weight_only_for_countable_or_weighable
    return if piece_weight_g.blank? || unit_group_mass? || unit_group_count?

    errors.add(:piece_weight_g, "ne s'applique qu'aux ingrédients en masse ou en pièces")
  end

  # Miroir exact de la règle ci-dessus, côté volume : le contenu d'une pièce ne
  # dit quelque chose que sur un ingrédient qui se verse ou qui se compte.
  def piece_volume_only_for_pourable_or_countable
    return if piece_volume_ml.blank? || unit_group_volume? || unit_group_count?

    errors.add(:piece_volume_ml, "ne s'applique qu'aux ingrédients en volume ou en pièces")
  end

  # Une pièce contient un poids OU un volume, jamais les deux : les deux
  # renseignés, PieceUnit devrait choisir lequel croire, et rien ne le
  # départagerait.
  def single_piece_measure
    return if piece_weight_g.blank? || piece_volume_ml.blank?

    errors.add(:piece_volume_ml, "ne se renseigne pas en même temps qu'un poids par pièce")
  end

  # Un nom de pièce sans rien pour compter les pièces ne pourrait rien afficher :
  # « brique » ne dit pas à lui seul combien de briques font 2 litres. Un
  # ingrédient déjà compté à la pièce, lui, se passe de coefficient — sa quantité
  # EST un nombre de pièces.
  def piece_label_needs_a_way_to_count
    return if piece_label.blank? || unit_group_count?
    return if piece_weight_g.present? || piece_volume_ml.present?

    errors.add(:piece_label, "demande le poids ou le volume d'une pièce pour être affiché")
  end

  # Un pluriel sans singulier ne désignerait rien.
  def piece_label_plural_accompanies_label
    return if piece_label_plural.blank? || piece_label.present?

    errors.add(:piece_label_plural, "ne se renseigne qu'avec un nom de pièce")
  end
end
