import { Controller } from "@hotwired/stimulus"

// Controller pour gérer les filtres de recherche de recettes
// - Sidebar gauche : filtres empilés verticalement
// - Tags déployables via panneau collapsible
// - Badges supprimables pour chaque filtre actif
// - Loader pendant le rechargement du Turbo Frame
// - Mobile : drawer latéral ouvert par bouton flottant
//
// Le formulaire vit hors du turbo-frame qu'il recharge : il n'est jamais
// re-rendu, donc le focus et le curseur restent dans le champ pendant la frappe.
export default class extends Controller {
  static targets = ["form", "loader", "results", "sidebar", "backdrop", "mobileTrigger"]

  // Attente avant de soumettre pendant la frappe : assez longue pour ne pas
  // partir à chaque lettre, assez courte pour que la liste suive la saisie
  // (même réglage que les filtres d'ingrédients, cf. filter_form_controller).
  static values = { delay: { type: Number, default: 300 } }

  connect() {
    this.hideLoader()
  }

  disconnect() {
    clearTimeout(this.debounceTimer)
  }

  // ── Sidebar mobile : ouvrir ──
  openSidebar() {
    if (this.hasSidebarTarget) this.sidebarTarget.classList.add("is-open")
    if (this.hasBackdropTarget) this.backdropTarget.classList.add("is-open")
    if (this.hasMobileTriggerTarget) this.mobileTriggerTarget.setAttribute("aria-expanded", "true")
    document.body.style.overflow = "hidden"
  }

  // ── Sidebar mobile : fermer ──
  closeSidebar() {
    if (this.hasSidebarTarget) this.sidebarTarget.classList.remove("is-open")
    if (this.hasBackdropTarget) this.backdropTarget.classList.remove("is-open")
    if (this.hasMobileTriggerTarget) this.mobileTriggerTarget.setAttribute("aria-expanded", "false")
    document.body.style.overflow = ""
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

  // Soumission immédiate : sélecteurs, cases à cocher, badges, touche Entrée.
  submit(event) {
    if (event) event.preventDefault()

    clearTimeout(this.debounceTimer)

    if (this.hasFormTarget) {
      this.showLoader()
      this.formTarget.requestSubmit()
      this.waitForFrameLoad()
    }
  }

  // Soumission différée pendant la frappe, une frappe chassant la précédente.
  submitDebounced() {
    clearTimeout(this.debounceTimer)
    this.debounceTimer = setTimeout(() => this.submit(), this.delayValue)
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
