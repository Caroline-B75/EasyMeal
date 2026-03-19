import { Controller } from "@hotwired/stimulus"

// Controller pour gérer les filtres de recherche de recettes avec loader
// Affiche un état de chargement pendant la recherche via Turbo Frame
export default class extends Controller {
  static targets = ["form", "loader", "results"]
  
  connect() {
    // S'assurer que le loader est caché au démarrage
    this.hideLoader()
  }
  
  // Soumettre le formulaire avec loader
  submit(event) {
    if (event) event.preventDefault()
    
    if (this.hasFormTarget) {
      this.showLoader()
      this.formTarget.requestSubmit()
      
      // Masquer le loader après le chargement du frame
      this.waitForFrameLoad()
    }
  }
  
  // Attendre le chargement du Turbo Frame
  waitForFrameLoad() {
    const frame = document.getElementById("recipes_list")
    if (frame) {
      const hideOnLoad = () => {
        this.hideLoader()
        frame.removeEventListener("turbo:frame-load", hideOnLoad)
      }
      frame.addEventListener("turbo:frame-load", hideOnLoad, { once: true })
      
      // Timeout de sécurité (5 secondes max)
      setTimeout(() => {
        this.hideLoader()
      }, 5000)
    }
  }
  
  // Afficher le loader
  showLoader() {
    if (this.hasLoaderTarget) {
      this.loaderTarget.classList.remove("hidden")
    }
    if (this.hasResultsTarget) {
      this.resultsTarget.classList.add("loading")
    }
  }
  
  // Masquer le loader
  hideLoader() {
    if (this.hasLoaderTarget) {
      this.loaderTarget.classList.add("hidden")
    }
    if (this.hasResultsTarget) {
      this.resultsTarget.classList.remove("loading")
    }
  }
  
  // Réinitialiser tous les filtres et rediriger vers la page sans filtres
  reset(event) {
    if (event) event.preventDefault()
    
    // Redirection simple vers la page des recettes sans paramètres
    window.location.href = this.formTarget.action
  }
}