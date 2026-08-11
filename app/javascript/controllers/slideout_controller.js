import { Controller } from "@hotwired/stimulus"

// Controller pour gérer un panneau latéral (slideout/sidebar)
// Utilisé pour afficher des formulaires sans quitter la page courante
// 
// Utilisation:
//   <div data-controller="slideout">
//     <button data-action="click->slideout#open">Ouvrir</button>
//     <div data-slideout-target="panel" class="slideout-panel">
//       <div data-slideout-target="content">Contenu chargé ici</div>
//     </div>
//   </div>
export default class extends Controller {
  static targets = ["panel", "overlay", "content"]
  static values = {
    url: String  // URL pour charger le contenu dynamiquement
  }

  connect() {
    // Écouter la touche Escape pour fermer
    this.boundHandleEscape = this.handleEscape.bind(this)
    document.addEventListener('keydown', this.boundHandleEscape)

    // Sauvegarder le HTML initial du formulaire pour pouvoir le réinitialiser
    const formContainer = this.panelTarget.querySelector('.slideout-content')
    if (formContainer) {
      this.initialFormHTML = formContainer.innerHTML
    }
  }

  disconnect() {
    document.removeEventListener('keydown', this.boundHandleEscape)
    this.enableBodyScroll()
  }

  // Ouvre le panneau latéral
  open(event) {
    if (event) event.preventDefault()

    // Réinitialiser le formulaire à son état initial (vide, sans erreurs)
    this.resetForm()
    
    this.panelTarget.classList.add("open")
    this.overlayTarget.classList.add("open")
    this.disableBodyScroll()
  }

  // Ferme le panneau latéral
  close(event) {
    if (event) event.preventDefault()

    this.panelTarget.classList.remove("open")
    this.overlayTarget.classList.remove("open")
    this.enableBodyScroll()

    // Fermeture = création abandonnée : prévient ceux qui attendaient un
    // ingrédient (ex: le panneau IA) pour qu'ils oublient leur ligne en attente.
    // Une création réussie ne passe pas par ici — ingredient-created referme le
    // panneau lui-même, une fois la ligne posée.
    this.dispatch("closed", { target: document })
  }

  // Ferme si on clique sur l'overlay
  closeOnOverlay(event) {
    if (event.target === this.overlayTarget) {
      this.close()
    }
  }

  // Gère la touche Escape
  handleEscape(event) {
    if (event.key === 'Escape' && this.panelTarget.classList.contains('open')) {
      this.close()
    }
  }

  // Réinitialise le contenu du slideout à son état initial
  // Supprime les erreurs de validation, vide les champs, ferme les options avancées
  resetForm() {
    const formContainer = this.panelTarget.querySelector('.slideout-content')
    if (formContainer && this.initialFormHTML) {
      formContainer.innerHTML = this.initialFormHTML
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
