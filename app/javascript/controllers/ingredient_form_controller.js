import { Controller } from "@hotwired/stimulus"

// Gère l'auto-fill de base_unit selon le unit_group sélectionné
// Utilisation:
//   <form data-controller="ingredient-form">
//     <select data-ingredient-form-target="unitGroup" data-action="change->ingredient-form#updateBaseUnit">
//     <input data-ingredient-form-target="baseUnit">
//   </form>
export default class extends Controller {
  static targets = ["unitGroup", "baseUnit"]

  // Mapping entre unit_group et base_unit
  static unitMap = {
    'mass': 'g',
    'volume': 'ml',
    'count': 'piece',
    'spoon': 'cac'
  }

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

    const selectedGroup = this.unitGroupTarget.value
    const baseUnit = this.constructor.unitMap[selectedGroup] || ''
    
    this.baseUnitTarget.value = baseUnit
  }
}
