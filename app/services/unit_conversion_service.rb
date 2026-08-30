# frozen_string_literal: true

# Ramène une quantité écrite dans n'importe quelle unité (« 20 cl », « 3 c. à
# s. ») à la quantité de base d'un ingrédient du catalogue.
#
# Le vocabulaire — quelles unités existent, comment elles s'écrivent, ce qu'elles
# valent les unes par rapport aux autres — vit dans Units et pas ici. Ce service
# n'ajoute que ce que Units ne peut pas savoir : les ponts qui dépendent de
# l'ingrédient lui-même.
#
# Ils sont deux, de même forme — un coefficient porté par l'ingrédient, et les
# facteurs universels de Units de part et d'autre :
#
#   - le contenu d'une pièce : ce qui se compte ↔ ce qui se mesure
#     (2 tranches → 80 g par piece_weight_g, 1 brique → 1 L par piece_volume_ml) ;
#   - density_g_per_ml : ce qui se mesure ↔ ce qui se pèse (1 càs → 8 g de farine).
#
# Aucun n'est deviné : sans le coefficient, la conversion échoue plutôt que de
# recopier le nombre, et c'est ce refus qui fait apparaître l'avertissement dans
# le panneau d'import.
class UnitConversionService
  class << self
    # Convertit une quantité+unité vers la quantity_base de l'ingrédient.
    # Retourne nil si la conversion est impossible : unité illisible, ou groupes
    # que ni équivalence universelle ni coefficient de l'ingrédient ne relient.
    #
    # Exemple :
    #   convert(quantity: 20, from_unit: "cl",  ingredient: creme)       → 200.0
    #   convert(quantity: 2,  from_unit: "càs", ingredient: huile_olive) → 30.0
    #   convert(quantity: 2,  from_unit: nil,   ingredient: jambon_40g)  → 80.0
    #   convert(quantity: 1,  from_unit: "càs", ingredient: farine_0_55) → 8.25
    #   convert(quantity: 1,  from_unit: "càs", ingredient: farine)      → nil (densité inconnue)
    def convert(quantity:, from_unit:, ingredient:)
      # Le chemin ordinaire : un facteur connu d'avance, au sein d'un groupe
      # d'unités ou d'un groupe à l'autre quand l'équivalence est universelle.
      factor = Units.factor_to(from_unit, ingredient.unit_group)
      return round3(quantity.to_f * factor) if factor
      return nil unless Units.definition(from_unit)

      bridge_by_piece_size(quantity.to_f, from_unit, ingredient) ||
        bridge_by_density(quantity.to_f, from_unit, ingredient)
    end

    # Retourne true si la quantité détectée peut atteindre l'unité de base de
    # l'ingrédient — directement ou par l'un de ses ponts.
    def compatible?(from_unit:, ingredient:)
      !convert(quantity: 1, from_unit: from_unit, ingredient: ingredient).nil?
    end

    # La densité de l'ingrédient débloquerait-elle cette conversion ? Autrement
    # dit : elle manque, et elle est le seul pont qui pourrait relier ces deux
    # façons de mesurer.
    #
    # C'est ce qui décide de demander une estimation à l'IA, et jamais une
    # conversion qu'aucune densité ne sauverait (« 2 tranches de lait ») : plutôt
    # que de redire ici quels groupes la densité relie, on essaie avec une
    # densité quelconque et on regarde si la conversion aboutit.
    def density_would_help?(from_unit:, ingredient:)
      return false if ingredient.density_g_per_ml.present?
      return false if compatible?(from_unit: from_unit, ingredient: ingredient)

      compatible?(from_unit: from_unit, ingredient: with_density(ingredient, 1.0))
    end

    # La conversion repose-t-elle sur une densité estimée par l'IA ? Même
    # raisonnement en creux : si la retirer casse la conversion, c'est elle qui
    # l'a rendue possible — et la quantité obtenue n'est juste qu'à une
    # estimation près, ce que la ligne d'import doit dire.
    def estimated?(from_unit:, ingredient:)
      return false unless ingredient.density_source_ai?
      return false unless compatible?(from_unit: from_unit, ingredient: ingredient)

      !compatible?(from_unit: from_unit, ingredient: with_density(ingredient, nil))
    end

    private

    # Ce que contient une pièce relie les deux façons de dire un même ingrédient :
    # la recette la compte (« 2 tranches », « 1 brique »), le catalogue la mesure
    # (g, ml). Le trajet est le même quelle que soit la mesure — d'où la question
    # posée une fois à l'ingrédient (cf. PieceCounting#piece_measure) plutôt que
    # deux ponts jumeaux côte à côte.
    def bridge_by_piece_size(quantity, from_unit, ingredient)
      size, measure_group = ingredient.piece_measure
      return nil if size.nil?

      if ingredient.unit_group == measure_group
        # « 2 tranches » de jambon → 80 g : des pièces vers la mesure.
        convert_through(quantity, from_unit, "count") { |pieces| pieces * size }
      elsif ingredient.unit_group_count?
        # « 200 g » d'oignon → 1,8 oignon : de la mesure vers les pièces.
        convert_through(quantity, from_unit, measure_group) { |measure| measure / size }
      end
    end

    # La densité relie ce qu'une recette mesure — un volume, une cuillère — à ce
    # que le catalogue pèse. Les 15 ml d'une cuillère à soupe sont universels
    # (Units), leur poids ne l'est pas : 8 g de farine, 21 g de miel.
    def bridge_by_density(quantity, from_unit, ingredient)
      density = ingredient.density_g_per_ml.to_f
      return nil unless density.positive?

      if ingredient.unit_group_mass?
        # « 1 càs de farine » : d'abord des millilitres, puis des grammes.
        convert_through(quantity, from_unit, "volume") { |millilitres| millilitres * density }
      else
        # « 200 g de miel » : des grammes, puis des millilitres, puis l'unité de
        # base de l'ingrédient — le millilitre, ou la cuillère à café.
        to_base = Units.factor_to("ml", ingredient.unit_group)
        to_base && convert_through(quantity, from_unit, "mass") { |grams| grams / density * to_base }
      end
    end

    # Amène la quantité dans l'unité de base d'un groupe intermédiaire (des
    # millilitres, des grammes, des pièces), puis laisse le coefficient de
    # l'ingrédient finir le trajet. Rend nil quand l'unité de départ ne rejoint
    # pas ce groupe : c'est ce qui écarte « 2 tranches » du pont des densités.
    def convert_through(quantity, from_unit, pivot_group)
      factor = Units.factor_to(from_unit, pivot_group)
      return nil unless factor

      round3(yield(quantity * factor))
    end

    # Un ingrédient identique, à sa densité près. Sert aux deux questions posées
    # en creux ci-dessus ; jamais sauvegardé.
    def with_density(ingredient, density)
      ingredient.dup.tap { |copy| copy.density_g_per_ml = density }
    end

    # Les quantités de base vivent au millième, ici comme en base.
    def round3(value)
      value.round(3)
    end
  end
end
