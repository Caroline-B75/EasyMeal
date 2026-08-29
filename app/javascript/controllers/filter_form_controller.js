import { Controller } from "@hotwired/stimulus"

// Formulaire de filtres qui se soumet de lui-même : il n'a pas de bouton d'envoi,
// chaque changement recharge directement les résultats dans le turbo-frame ciblé.
//
// Le formulaire vit hors de ce frame, donc il n'est jamais re-rendu : le focus et
// le curseur restent dans le champ pendant la frappe, mais c'est à lui de tenir à
// jour la visibilité du lien « Effacer les filtres ».
//
// Usage : data-controller="filter-form" sur le <form>, puis sur chaque champ
//         data-action="change->filter-form#submit" (sélecteurs, cases à cocher)
//         ou "input->filter-form#submitDebounced" (champs texte).
export default class extends Controller {
  static targets = ["clear"]

  // Attente avant de soumettre pendant la frappe : assez longue pour ne pas
  // partir à chaque lettre, assez courte pour que la liste suive la saisie.
  static values = { delay: { type: Number, default: 300 } }

  connect() {
    this.toggleClear()
  }

  disconnect() {
    clearTimeout(this.debounceTimer)
  }

  // Soumission immédiate : sélecteurs, cases à cocher, touche Entrée.
  submit(event) {
    if (event) event.preventDefault()

    clearTimeout(this.debounceTimer)
    this.toggleClear()
    this.element.requestSubmit()
  }

  // Soumission différée, une frappe chassant la précédente.
  submitDebounced() {
    clearTimeout(this.debounceTimer)
    this.debounceTimer = setTimeout(() => this.submit(), this.delayValue)
  }

  // Effacer les filtres n'a de sens que s'il y en a au moins un de posé.
  toggleClear() {
    if (this.hasClearTarget) this.clearTarget.classList.toggle("hidden", !this.hasActiveFilter)
  }

  get hasActiveFilter() {
    // Les champs cachés (jeton Rails, valeur de repli d'une case) ne sont pas des filtres.
    const fields = this.element.querySelectorAll("input:not([type=hidden]), select")

    return Array.from(fields).some((field) => (field.type === "checkbox" ? field.checked : field.value !== ""))
  }
}
