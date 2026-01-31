import { Controller } from "@hotwired/stimulus"

// Controller pour scroller automatiquement vers le premier champ en erreur
export default class extends Controller {
  connect() {
    // Chercher le premier champ avec une erreur
    const firstErrorField = this.element.querySelector(".has-error, .field-errors")
    
    if (firstErrorField) {
      // Trouver le champ parent (.form-group) pour un meilleur positionnement
      const formGroup = firstErrorField.closest(".form-group") || firstErrorField
      
      // Scroll smooth vers le premier champ en erreur avec un peu de marge
      setTimeout(() => {
        formGroup.scrollIntoView({ behavior: "smooth", block: "center" })
        
        // Focus sur le champ input/select si possible
        const input = formGroup.querySelector("input, select, textarea")
        if (input) {
          input.focus({ preventScroll: true })
        }
      }, 100)
    }
  }
}
