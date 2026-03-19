import { Controller } from "@hotwired/stimulus"

// Controller pour gérer les filtres de recherche de recettes
// - Filtres principaux toujours visibles + tags déployables
// - Badges supprimables pour chaque filtre actif
// - Loader pendant le rechargement du Turbo Frame
export default class extends Controller {
  static targets = ["form", "loader", "results", "panel", "toggleBtn"]

  connect() {
    this.hideLoader()
    if (this.hasPanelTarget && this.hasToggleBtnTarget) {
      const isOpen = !this.panelTarget.classList.contains("hidden")
      this.toggleBtnTarget.setAttribute("aria-expanded", String(isOpen))
    }
  }

  // Ouvrir / fermer le panneau tags
  togglePanel(event) {
    if (event) event.preventDefault()
    if (!this.hasPanelTarget) return

    const isOpen = this.panelTarget.classList.toggle("hidden") === false

    if (this.hasToggleBtnTarget) {
      this.toggleBtnTarget.setAttribute("aria-expanded", String(isOpen))
    }
  }

  // Supprimer un filtre individuel via son badge ×
  clearFilter(event) {
    event.preventDefault()
    const field = event.currentTarget.dataset.recipeFilterField
    const value = event.currentTarget.dataset.recipeFilterValue

    if (field === "tag_ids[]") {
      // Décocher uniquement la checkbox du tag concerné
      this.formTarget.querySelectorAll('input[name="tag_ids[]"]').forEach(cb => {
        if (String(cb.value) === String(value)) cb.checked = false
      })
    } else if (field === "seasonal" || field === "favorites") {
      const cb = this.formTarget.querySelector(`input[type="checkbox"][name="${field}"]`)
      if (cb) cb.checked = false
    } else {
      const el = this.formTarget.querySelector(`[name="${field}"]`)
      if (el) el.value = ""
    }

    this.submit()
  }

  // Soumettre le formulaire avec loader
  submit(event) {
    if (event) event.preventDefault()

    if (this.hasFormTarget) {
      this.showLoader()
      this.formTarget.requestSubmit()
      this.waitForFrameLoad()
    }
  }

  waitForFrameLoad() {
    const frame = document.getElementById("recipes_list")
    if (frame) {
      frame.addEventListener("turbo:frame-load", () => this.hideLoader(), { once: true })
      setTimeout(() => this.hideLoader(), 5000)
    }
  }

  showLoader() {
    if (this.hasLoaderTarget) this.loaderTarget.classList.remove("hidden")
    if (this.hasResultsTarget) this.resultsTarget.classList.add("loading")
  }

  hideLoader() {
    if (this.hasLoaderTarget) this.loaderTarget.classList.add("hidden")
    if (this.hasResultsTarget) this.resultsTarget.classList.remove("loading")
  }

  reset(event) {
    if (event) event.preventDefault()
    window.location.href = this.formTarget.action
  }
}
