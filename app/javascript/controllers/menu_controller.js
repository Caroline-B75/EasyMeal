import { Controller } from "@hotwired/stimulus"

// Controller pour gérer l'ouverture/fermeture du menu utilisateur
export default class extends Controller {
  static targets = ["dropdown", "button"]

  // Toggle le menu au clic
  toggle(event) {
    event.preventDefault()
    event.stopPropagation()
    
    this.dropdownTarget.classList.toggle("active")
    this.buttonTarget.classList.toggle("active")
    
    // Ajouter/retirer le listener de clic sur le document
    if (this.dropdownTarget.classList.contains("active")) {
      document.addEventListener("click", this.closeOnClickOutside.bind(this))
    } else {
      document.removeEventListener("click", this.closeOnClickOutside.bind(this))
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
    document.removeEventListener("click", this.closeOnClickOutside.bind(this))
  }

  // Nettoyage lors de la destruction du controller
  disconnect() {
    document.removeEventListener("click", this.closeOnClickOutside.bind(this))
  }
}
