import { Controller } from "@hotwired/stimulus"
import { enqueueToggle, queuedState } from "offline_queue"

/**
 * Toggle visuel optimiste pour les items de la liste de courses (UC3 + R0.3).
 * Au clic sur le bouton coché/décoché, applique immédiatement les classes CSS
 * avant la réponse serveur — le Turbo Stream confirme ou corrige ensuite.
 *
 * Hors-ligne (usage en magasin) : le PATCH échoue faute de réseau. On conserve
 * l'état optimiste et on met le toggle en file d'attente (offline_queue) pour
 * synchroniser le serveur au retour de connexion.
 *
 * Usage (sur l'élément .grocery-item) :
 *   .grocery-item{ data: { controller: "grocery-check" } }
 *     %button{ data: { action: "click->grocery-check#toggle",
 *                      "grocery-check-target": "checkbox" } }
 *     %span{ data: { "grocery-check-target": "label" } }
 * Le formulaire du bouton doit relayer :
 *     data: { action: "turbo:submit-end->grocery-check#submitEnd" }
 */
export default class extends Controller {
  static targets = ["checkbox", "label"]

  /**
   * Réhydrate l'affichage depuis la file d'attente hors-ligne : si un toggle
   * de cet item est en attente, le HTML servi par le cache (état de la dernière
   * visite en ligne) est réaligné sur l'intention de l'utilisateur.
   */
  connect() {
    const url = this.toggleUrl
    if (!url) return

    const pending = queuedState(url)
    if (pending !== undefined) this.applyChecked(pending)
  }

  /**
   * Bascule les classes CSS immédiatement (feedback optimiste).
   * Le Turbo Stream du serveur remplacera l'élément avec l'état confirmé.
   */
  toggle() {
    this.applyChecked(!this.element.classList.contains("grocery-item--checked"))
  }

  /**
   * Fin de soumission du PATCH de toggle.
   * - Succès (en ligne) : le serveur a répondu, le Turbo Stream re-rend le
   *   rayon avec l'état confirmé → rien à faire.
   * - Échec RÉSEAU (hors-ligne) : aucune réponse HTTP reçue. On garde l'état
   *   optimiste déjà appliqué et on met le toggle en file d'attente.
   * - Échec avec réponse HTTP (422/500 en ligne) : on n'enfile pas, c'est une
   *   erreur serveur et non un problème de connexion.
   */
  submitEnd(event) {
    const { success, fetchResponse } = event.detail
    if (success || fetchResponse) return

    const url = this.toggleUrl
    if (!url) return

    enqueueToggle(url, this.element.classList.contains("grocery-item--checked"))
  }

  // URL du PATCH de toggle (action du formulaire du bouton checkbox).
  get toggleUrl() {
    return this.hasCheckboxTarget ? this.checkboxTarget.form?.action : null
  }

  // Applique un état "coché" déterministe sur l'item, le bouton et le libellé.
  applyChecked(checked) {
    this.element.classList.toggle("grocery-item--checked", checked)
    if (this.hasCheckboxTarget) {
      this.checkboxTarget.classList.toggle("btn-checkbox--checked", checked)
    }
    if (this.hasLabelTarget) {
      this.labelTarget.classList.toggle("grocery-item-name--checked", checked)
    }
  }
}
