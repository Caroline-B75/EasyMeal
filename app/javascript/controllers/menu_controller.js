import { Controller } from "@hotwired/stimulus"

// Controller pour gérer l'ouverture/fermeture du menu utilisateur
export default class extends Controller {
  static targets = ["dropdown", "button"]

  connect() {
    // Handler lié une seule fois : indispensable pour que removeEventListener
    // retire bien le même listener (un .bind() par appel créerait des références
    // distinctes, jamais retirées).
    this.closeOnClickOutside = this.closeOnClickOutside.bind(this)
  }

  // Toggle le menu au clic
  toggle(event) {
    event.preventDefault()
    event.stopPropagation()

    const isOpen = this.dropdownTarget.classList.toggle("active")
    this.buttonTarget.classList.toggle("active", isOpen)
    this.buttonTarget.setAttribute("aria-expanded", String(isOpen))

    // Ajouter/retirer le listener de clic sur le document
    if (isOpen) {
      document.addEventListener("click", this.closeOnClickOutside)
    } else {
      document.removeEventListener("click", this.closeOnClickOutside)
    }
  }

  // Fermer le menu si on clique en dehors
  closeOnClickOutside(event) {
    if (!this.element.contains(event.target)) {
      this.close()
    }
  }

  // Fermer le menu
  close() {
    this.dropdownTarget.classList.remove("active")
    this.buttonTarget.classList.remove("active")
    this.buttonTarget.setAttribute("aria-expanded", "false")
    document.removeEventListener("click", this.closeOnClickOutside)
  }

  // Nettoyage lors de la destruction du controller
  disconnect() {
    document.removeEventListener("click", this.closeOnClickOutside)
  }
}
