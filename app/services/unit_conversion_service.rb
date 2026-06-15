class UnitConversionService
  # Table de conversion : unité IA → { unit_group de l'ingrédient, facteur vers base_unit }
  # base_units : g (mass), ml (volume), cac (spoon), piece (count)
  CONVERSIONS = {
    "g"       => { unit_group: "mass",   factor: 1.0 },
    "kg"      => { unit_group: "mass",   factor: 1000.0 },
    "ml"      => { unit_group: "volume", factor: 1.0 },
    "cl"      => { unit_group: "volume", factor: 10.0 },
    "dl"      => { unit_group: "volume", factor: 100.0 },
    "l"       => { unit_group: "volume", factor: 1000.0 },
    "càc"     => { unit_group: "spoon",  factor: 1.0 },
    "cac"     => { unit_group: "spoon",  factor: 1.0 },
    "càs"     => { unit_group: "spoon",  factor: 3.0 },
    "cas"     => { unit_group: "spoon",  factor: 3.0 },
    "piece"   => { unit_group: "count",  factor: 1.0 },
    "pièce"   => { unit_group: "count",  factor: 1.0 },
    "pièces"  => { unit_group: "count",  factor: 1.0 },
    nil       => { unit_group: "count",  factor: 1.0 }
  }.freeze

  # Convertit une quantité+unité vers la quantity_base de l'ingrédient.
  # Retourne nil si la conversion est impossible (unit_group incompatible).
  #
  # Exemple :
  #   convert(quantity: 20, from_unit: "cl", ingredient: creme_fraiche) → 200.0
  #   convert(quantity: 2,  from_unit: "càs", ingredient: beurre)       → nil  (mass ≠ spoon)
  def self.convert(quantity:, from_unit:, ingredient:)
    normalized = from_unit&.downcase&.strip
    conversion = CONVERSIONS[normalized] || CONVERSIONS[from_unit]
    return nil unless conversion
    return nil unless conversion[:unit_group] == ingredient.unit_group

    (quantity.to_f * conversion[:factor]).round(3)
  end

  # Retourne true si l'unité est connue et compatible avec le unit_group de l'ingrédient.
  def self.compatible?(from_unit:, ingredient:)
    !convert(quantity: 1, from_unit: from_unit, ingredient: ingredient).nil?
  end
end
