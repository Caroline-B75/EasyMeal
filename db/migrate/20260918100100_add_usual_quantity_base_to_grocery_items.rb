# frozen_string_literal: true

# La part d'une ligne de courses qui vient des courses habituelles.
#
# Une ligne additionne sa part (menu ou ajout ponctuel) et sa part habituelle :
# la première est recalculée à chaque validation du menu, la seconde est
# conservée. Vide quand la ligne ne doit rien aux habituels.
class AddUsualQuantityBaseToGroceryItems < ActiveRecord::Migration[8.1]
  def change
    add_column :grocery_items, :usual_quantity_base, :decimal, precision: 10, scale: 3
  end
end
