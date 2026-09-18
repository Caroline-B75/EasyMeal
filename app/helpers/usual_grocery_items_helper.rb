# frozen_string_literal: true

# Courses habituelles du foyer (UC8, étape 3)
module UsualGroceryItemsHelper
  # Pas des boutons − / + pour une unité de saisie, quand il diffère de 1 : à
  # l'unité, des grammes ou des millilitres ne bougeraient pas à l'œil.
  USUAL_GROCERY_STEPS = { "g" => 50, "ml" => 50, "cl" => 5 }.freeze

  # Le titre de la liste : « Nos » dans un foyer partagé, « Mes » seul.
  # @param household [Household]
  # @return [String]
  def usual_groceries_title(household)
    household.shared? ? "Nos courses habituelles" : "Mes courses habituelles"
  end

  # Unités proposées pour une course habituelle : celles de son ingrédient s'il
  # est au catalogue — « 20 cl de curcuma » n'a pas de sens —, toutes sinon.
  # Mêmes choix que le formulaire « Ajouter un article » (cf. ingredient-combobox).
  # @param item [UsualGroceryItem]
  # @return [Array<Array(String, String)>]
  def usual_grocery_unit_options(item)
    item.ingredient ? Units.select_options(item.ingredient.unit_group) : Units.all_select_options
  end

  # La quantité d'une course habituelle telle qu'on la lit : « 6 L », « 250 g »,
  # et « 2 » pour ce qui se compte.
  # @param item [UsualGroceryItem]
  # @return [String]
  def usual_grocery_quantity_label(item)
    [ item.quantity_for_input.to_s.tr(".", ","), usual_grocery_unit_suffix(item) ].compact_blank.join(" ")
  end

  # L'unité écrite après une quantité : rien pour ce qui se compte — « 2 pièce »
  # ne dirait rien de plus que « 2 ».
  # @param item [UsualGroceryItem]
  # @return [String]
  def usual_grocery_unit_suffix(item)
    item.unit == Units::DEFAULT_UNIT ? "" : item.unit_label
  end

  # Pas des boutons − / + pour une unité : un par un en litres, kilos, pièces
  # ou cuillères ; par 50 g ou 50 ml, par 5 cl.
  # @param unit [String] unité canonique
  # @return [Integer]
  def usual_grocery_step(unit)
    USUAL_GROCERY_STEPS.fetch(unit, 1)
  end
end
