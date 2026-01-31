import { Controller } from "@hotwired/stimulus"

// Controller pour afficher dynamiquement l'unité de base d'un ingrédient
// lorsqu'il est sélectionné dans le formulaire de préparation
export default class extends Controller {
  static targets = ["select", "display"]

  connect() {
    // Afficher l'unité si un ingrédient est déjà sélectionné
    this.updateUnit()
  }

  // Appelé quand la sélection de l'ingrédient change
  updateUnit() {
    const select = this.selectTarget
    const selectedOption = select.options[select.selectedIndex]

    if (selectedOption && selectedOption.value) {
      // Récupérer l'unité depuis l'attribut data de l'option
      const unit = selectedOption.dataset.unit
      if (unit) {
        this.displayTarget.textContent = unit
        this.displayTarget.classList.remove("text-muted")
      } else {
        this.displayTarget.textContent = "—"
        this.displayTarget.classList.add("text-muted")
      }
    } else {
      this.displayTarget.textContent = "—"
      this.displayTarget.classList.add("text-muted")
    }
  }
}
