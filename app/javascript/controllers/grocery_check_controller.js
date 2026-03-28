import { Controller } from "@hotwired/stimulus"

/**
 * Toggle visuel optimiste pour les items de la liste de courses (UC3).
 * Au clic sur le bouton coché/décoché, applique immédiatement les classes CSS
 * avant la réponse serveur — le Turbo Stream confirme ou corrige ensuite.
 *
 * Usage (sur l'élément .grocery-item) :
 *   .grocery-item{ data: { controller: "grocery-check" } }
 *     %button{ data: { action: "click->grocery-check#toggle",
 *                      "grocery-check-target": "checkbox" } }
 *     %span{ data: { "grocery-check-target": "label" } }
 */
export default class extends Controller {
  static targets = ["checkbox", "label"]

  /**
   * Bascule les classes CSS immédiatement (feedback optimiste).
   * Le Turbo Stream du serveur remplacera l'élément avec l'état confirmé.
   */
  toggle() {
    // Toggle de l'item parent
    this.element.classList.toggle("grocery-item--checked")

    // Toggle du bouton checkbox
    if (this.hasCheckboxTarget) {
      this.checkboxTarget.classList.toggle("btn-checkbox--checked")
    }

    // Toggle du texte barré sur le nom
    if (this.hasLabelTarget) {
      this.labelTarget.classList.toggle("grocery-item-name--checked")
    }
  }
}
