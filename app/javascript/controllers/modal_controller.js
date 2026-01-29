import { Controller } from "@hotwired/stimulus"

// Gère l'ouverture/fermeture des modals de confirmation
// Utilisation:
//   <div data-controller="modal">
//     <button data-action="modal#open">Ouvrir</button>
//     <div data-modal-target="overlay" class="modal-overlay">...</div>
//   </div>
export default class extends Controller {
  static targets = ["overlay", "confirmButton"]

  connect() {
    // Écouter la touche Escape pour fermer
    this.boundHandleEscape = this.handleEscape.bind(this)
    document.addEventListener('keydown', this.boundHandleEscape)
  }

  disconnect() {
    document.removeEventListener('keydown', this.boundHandleEscape)
    this.enableBodyScroll()
  }

  // Ouvre la modal et stocke le formulaire à soumettre
  open(event) {
    event.preventDefault()
    
    // Stocke le formulaire qui a déclenché l'ouverture
    this.formToSubmit = event.target.closest('form')
    
    // Affiche la modal
    this.overlayTarget.style.display = 'flex'
    
    // Bloque le scroll de la page
    this.disableBodyScroll()
  }

  // Ferme la modal
  close(event) {
    if (event) {
      event.preventDefault()
    }
    
    this.overlayTarget.style.display = 'none'
    this.formToSubmit = null
    this.enableBodyScroll()
  }

  // Confirme l'action et soumet le formulaire
  confirm(event) {
    event.preventDefault()
    
    if (this.formToSubmit) {
      this.formToSubmit.submit()
    }
    
    this.close()
  }

  // Ferme si on clique sur l'overlay (en dehors du contenu)
  closeOnOverlay(event) {
    if (event.target === this.overlayTarget) {
      this.close()
    }
  }

  // Gère la touche Escape
  handleEscape(event) {
    if (event.key === 'Escape' && this.overlayTarget.style.display === 'flex') {
      this.close()
    }
  }

  // Utilitaires pour gérer le scroll du body
  disableBodyScroll() {
    document.body.style.overflow = 'hidden'
  }

  enableBodyScroll() {
    document.body.style.overflow = ''
  }
}
