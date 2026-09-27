# frozen_string_literal: true

# La part d'une ligne du menu ajoutée en plus, à la main, par le formulaire
# « Ajouter un article » : le beurre de la recette, et celui qu'on rajoute.
#
# Comme la part habituelle, elle est comprise dans `quantity_base` et conservée
# à chaque validation du menu, qui ne recalcule que la part du menu. Vide quand
# la ligne ne porte rien en plus — toujours pour un ajout ponctuel, dont toute
# la quantité est déjà « à la main ». Elle ne s'affiche pas : elle ne sert qu'à
# ne pas perdre ce qu'on a ajouté.
class AddExtraQuantityBaseToGroceryItems < ActiveRecord::Migration[8.1]
  def change
    add_column :grocery_items, :extra_quantity_base, :decimal, precision: 10, scale: 3
  end
end
