import { Controller } from "@hotwired/stimulus"

/**
 * Contrôleur Stimulus pour l'édition inline des paramètres du menu brouillon.
 *
 * Gère :
 * - Sauvegarde automatique du nom au blur (formulaire PATCH → Turbo Stream)
 * - Stepper +/- pour le nombre de personnes (formulaire PATCH → Turbo Stream)
 * - Dropdown du sélecteur de régime alimentaire (ouverture / fermeture / click-outside)
 */
export default class extends Controller {
  static targets = [
    "nameForm", "nameInput",
    "peopleForm", "peopleInput", "peopleDisplay",
    "dietPicker", "dietToggle", "dietOptions"
  ]

  connect() {
    // Ferme le dropdown régime lorsque l'utilisateur clique hors du composant
    this.boundClickOutside = this.clickOutside.bind(this)
    document.addEventListener("click", this.boundClickOutside)

    // Référence pour ne pas déclencher de PATCH si le nom n'a pas changé
    this.savedName = this.hasNameInputTarget ? this.nameInputTarget.value : null
  }

  disconnect() {
    document.removeEventListener("click", this.boundClickOutside)
  }

  // ── Nom du menu ─────────────────────────────────────────────

  // Le crayon n'est qu'une affordance : il donne le focus au champ du titre
  focusName() {
    this.nameInputTarget.focus()
    this.nameInputTarget.select()
  }

  // Déclenché par l'événement blur sur le champ nom.
  // Un blur sans modification (simple clic ailleurs) ne doit pas re-rendre l'en-tête.
  saveName() {
    if (this.nameInputTarget.value === this.savedName) return

    this.savedName = this.nameInputTarget.value
    this.nameFormTarget.requestSubmit()
  }

  // Sur Enter dans le champ nom : enlève le focus → déclenche saveName via blur
  blurName(event) {
    event.preventDefault()
    event.target.blur()
  }

  // ── Nombre de personnes ─────────────────────────────────────

  incrementPeople() {
    const current = parseInt(this.peopleInputTarget.value)
    if (current < 12) this._applyPeople(current + 1)
  }

  decrementPeople() {
    const current = parseInt(this.peopleInputTarget.value)
    if (current > 1) this._applyPeople(current - 1)
  }

  // Met à jour l'affichage optimistiquement, puis soumet le formulaire
  _applyPeople(value) {
    this.peopleInputTarget.value = value
    this.peopleDisplayTarget.textContent = value
    this.peopleFormTarget.requestSubmit()
  }

  // ── Sélecteur de régime alimentaire ────────────────────────

  toggleDietPicker(event) {
    event.stopPropagation()
    const isOpen = !this.dietOptionsTarget.hidden
    this.dietOptionsTarget.hidden = isOpen
    this.dietToggleTarget.setAttribute("aria-expanded", String(!isOpen))
  }

  // Ferme le dropdown si le clic est extérieur au composant .mc-diet-picker
  clickOutside(event) {
    if (!this.hasDietPickerTarget) return
    if (!this.dietPickerTarget.contains(event.target)) {
      this.dietOptionsTarget.hidden = true
      this.dietToggleTarget.setAttribute("aria-expanded", "false")
    }
  }
}
