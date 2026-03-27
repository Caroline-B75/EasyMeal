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

  // Appelé après création réussie d'un ingrédient
  // Rafraîchit les selects d'ingrédients et ferme le panneau
  ingredientCreated(event) {
    const { id, name, displayName, baseUnit } = event.detail
    
    // Mettre à jour tous les selects d'ingrédients dans la page
    document.querySelectorAll('select[name*="ingredient_id"]').forEach(select => {
      // Vérifier si l'ingrédient n'existe pas déjà
      if (!select.querySelector(`option[value="${id}"]`)) {
        // Créer une nouvelle option
        const option = document.createElement('option')
        option.value = id
        option.textContent = displayName
        option.dataset.unit = baseUnit
        
        // Insérer en ordre alphabétique
        const options = Array.from(select.querySelectorAll('option')).slice(1) // Skip first "Choisir..."
        const insertIndex = options.findIndex(opt => opt.textContent.localeCompare(displayName) > 0)
        
        if (insertIndex === -1) {
          select.appendChild(option)
        } else {
          select.insertBefore(option, options[insertIndex])
        }
      }
    })
    
    // Fermer le panneau
    this.close()
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
