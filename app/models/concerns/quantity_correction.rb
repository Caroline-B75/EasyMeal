# frozen_string_literal: true

# Corriger la quantité d'une ligne de courses dans l'unité où on l'achète :
# « 2 plaquettes » de beurre, pas « 500 g ».
#
# La saisie rejoint l'unité de base par le chemin des recettes et de « Ajouter
# un article » (UnitConversionService) : la ligne recopie le groupe d'unités et
# la pièce de son ingrédient (cf. PieceCounting), elle a donc de quoi convertir
# seule — même après le retrait de cet ingrédient du catalogue.
module QuantityCorrection
  extend ActiveSupport::Concern

  # Les unités dans lesquelles corriger la quantité (celles de la saisie, cf.
  # PieceCounting#unit_select_options), chacune avec ce que la ligne y vaut —
  # ce que le champ affiche quand on la choisit.
  # @return [Array<Array(String, String, Numeric)>] [[libellé, unité, quantité]]
  def quantity_edit_options
    unit_select_options.filter_map do |label, unit|
      factor = unit_factor(unit)
      [ label, unit, quantity_in(unit, factor) ] if factor
    end
  end

  # L'unité dans laquelle s'ouvre la correction : la pièce pour ce qui s'achète
  # à la pièce, comme la ligne l'affiche ; l'unité de base sinon.
  # @return [String]
  def quantity_edit_unit
    counted_by_piece? && unit_factor(Units::DEFAULT_UNIT) ? Units::DEFAULT_UNIT : base_unit
  end

  # Remplace la quantité par une saisie — « 2 » « piece » —, ramenée à l'unité
  # de base de la ligne. Seules les unités proposées sont acceptées.
  # @param quantity [String, Numeric]
  # @param unit [String, nil] unité canonique ; l'unité de base à défaut
  # @return [Boolean] false, avec une erreur, si l'unité ne convient pas à la ligne
  def enter_quantity(quantity, unit)
    unit = unit.presence || base_unit
    factor = unit_select_options.any? { |_label, option| option == unit } && unit_factor(unit)
    unless factor
      errors.add(:base, "L'unité « #{Units.label(unit)} » ne convient pas à #{name}")
      return false
    end

    self.quantity_base = (quantity.to_s.to_d * factor.to_d).round(3)
    true
  end

  # Une ligne ne recopie pas la densité de son ingrédient : aucune unité qu'on
  # lui propose n'en a besoin (la cuillère d'un liquide est universelle). Rend
  # la réponse explicite à UnitConversionService, qui la demande en dernier
  # recours.
  # @return [nil]
  def density_g_per_ml
    nil
  end

  private

  # Ce que vaut une unité saisie dans l'unité de base de la ligne, sans arrondi
  # (cf. UnitConversionService.factor) ; nil si rien ne la relie à la ligne.
  # @param unit [String]
  # @return [Float, nil]
  def unit_factor(unit)
    UnitConversionService.factor(from_unit: unit, ingredient: self)
  end

  # La quantité de la ligne dite dans une autre unité, telle que le champ de
  # correction l'affiche. En pièces, sur ce qui se pèse ou se verse, c'est le
  # compte qu'on lit sur la ligne, arrondi au supérieur (« 1 plaquette pour
  # 40 g ») : rouvrir la correction ne doit pas montrer 0,16 plaquette.
  # @param unit [String]
  # @param factor [Float] cf. unit_factor
  # @return [Numeric]
  def quantity_in(unit, factor)
    return piece_unit.count_for(quantity_base) if unit == Units::DEFAULT_UNIT && !unit_group_count?

    (quantity_base / factor.to_d).round(3)
  end
end
