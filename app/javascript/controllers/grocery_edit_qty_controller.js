import { Controller } from "@hotwired/stimulus"

// Bascule entre affichage de la quantité et formulaire d'édition inline.
// L'état initial (masqué) est géré par CSS, pas par JS, pour éviter tout flash au chargement.
export default class extends Controller {
  static targets = ["input"]

  edit() {
    this.element.classList.add("is-editing")
    this.inputTarget.focus()
    this.inputTarget.select()
  }

  cancel() {
    this.element.classList.remove("is-editing")
  }

  handleKeydown(event) {
    if (event.key === "Escape") {
      event.preventDefault()
      this.cancel()
    }
  }
}
