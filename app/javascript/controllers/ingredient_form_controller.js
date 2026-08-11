import { Controller } from "@hotwired/stimulus"

// Gère l'auto-fill de base_unit selon le unit_group sélectionné.
// La correspondance groupe → unité de base n'est PAS codée ici : elle vient de
// Ingredient::BASE_UNITS, sérialisée par les partials de formulaire.
// Utilisation (HAML) :
//   = simple_form_for ingredient, html: { data: { controller: "ingredient-form",
//       ingredient_form_units_value: Ingredient::BASE_UNITS } } do |f|
//     -# select data-ingredient-form-target="unitGroup"
//     -#        data-action="change->ingredient-form#updateBaseUnit"
//     -# input  data-ingredient-form-target="baseUnit"
export default class extends Controller {
  static targets = ["unitGroup", "baseUnit"]
  static values = { units: Object }

  connect() {
    // Si un unit_group est déjà sélectionné au chargement, remplir base_unit
    if (this.hasUnitGroupTarget && this.unitGroupTarget.value) {
      this.updateBaseUnit()
    }
  }

  // Met à jour l'unité de base selon le groupe d'unités sélectionné
  updateBaseUnit() {
    if (!this.hasBaseUnitTarget || !this.hasUnitGroupTarget) {
      return
    }

    this.baseUnitTarget.value = this.unitsValue[this.unitGroupTarget.value] || ""
  }
}
