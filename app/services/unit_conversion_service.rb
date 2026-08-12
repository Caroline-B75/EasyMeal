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
  # Retourne nil si la conversion est impossible (unit_group incompatible et
  # aucun poids unitaire pour faire le pont).
  #
  # Exemple :
  #   convert(quantity: 20, from_unit: "cl", ingredient: creme_fraiche) → 200.0
  #   convert(quantity: 2,  from_unit: nil,  ingredient: jambon_40g)    → 80.0
  #   convert(quantity: 2,  from_unit: "càs", ingredient: beurre)       → nil  (mass ≠ spoon)
  def self.convert(quantity:, from_unit:, ingredient:)
    conversion = lookup(from_unit)
    return nil unless conversion

    # D'abord vers l'unité de base du groupe *détecté* (kg → g, cl → ml) : le
    # pont ci-dessous raisonne alors sur des grammes et des pièces, jamais sur
    # l'unité d'origine.
    amount = quantity.to_f * conversion[:factor]
    return amount.round(3) if conversion[:unit_group] == ingredient.unit_group

    bridge_by_piece_weight(amount, conversion[:unit_group], ingredient)
  end

  # Retourne true si la quantité détectée peut atteindre l'unité de base de
  # l'ingrédient — directement ou via son poids unitaire.
  def self.compatible?(from_unit:, ingredient:)
    !convert(quantity: 1, from_unit: from_unit, ingredient: ingredient).nil?
  end

  # Le poids d'une pièce relie les deux façons de dire un même ingrédient : la
  # recette le compte (« 2 tranches »), le catalogue le pèse (g). Sans ce poids
  # renseigné, la conversion échoue au lieu de recopier le nombre : c'est ce
  # refus qui fait apparaître l'avertissement dans le panneau d'import.
  # Les autres croisements (cuillères ↔ masse, pièces ↔ volume) dépendent de
  # l'ingrédient bien plus que d'un facteur unique : ils restent hors de portée.
  def self.bridge_by_piece_weight(amount, from_group, ingredient)
    weight = ingredient.piece_weight_g.to_f
    return nil unless weight.positive?

    case [ from_group, ingredient.unit_group ]
    when %w[count mass] then (amount * weight).round(3)
    when %w[mass count] then (amount / weight).round(3)
    end
  end
  private_class_method :bridge_by_piece_weight

  # nil est une clé légitime de la table (« 3 oeufs » arrive sans unité) ; toute
  # autre unité qu'elle ignore n'est simplement pas convertible.
  def self.lookup(from_unit)
    CONVERSIONS[from_unit&.downcase&.strip]
  end
  private_class_method :lookup
end
