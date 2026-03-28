import { Controller } from "@hotwired/stimulus"

/**
 * Soumet automatiquement le formulaire "nombre de personnes" après une pause
 * de saisie (debounce), évitant de cliquer sur le bouton ✓.
 *
 * Usage :
 *   <form data-controller="people-counter">
 *     <input type="number"
 *            data-action="input->people-counter#scheduleSubmit">
 *   </form>
 */
export default class extends Controller {
  static values = {
    delay: { type: Number, default: 800 }
  }

  connect() {
    this.timer = null
  }

  disconnect() {
    this.clearTimer()
  }

  // Planifie la soumission après délai (reset à chaque frappe)
  scheduleSubmit() {
    this.clearTimer()
    this.timer = setTimeout(() => {
      this.element.requestSubmit()
    }, this.delayValue)
  }

  // Soumission immédiate (utilisée par le bouton ✓ explicite)
  submitNow(event) {
    event.preventDefault()
    this.clearTimer()
    this.element.requestSubmit()
  }

  clearTimer() {
    if (this.timer) {
      clearTimeout(this.timer)
      this.timer = null
    }
  }
}
