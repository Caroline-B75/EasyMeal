import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["toggleBtn"]

  get accordionControllers() {
    return Array.from(
      this.element.querySelectorAll("[data-controller~='grocery-accordion']")
    ).map(el =>
      this.application.getControllerForElementAndIdentifier(el, "grocery-accordion")
    ).filter(Boolean)
  }

  toggleAll() {
    const allOpen = this.accordionControllers.every(c => c.openValue)
    this.accordionControllers.forEach(c => (allOpen ? c.close() : c.open()))
    this.syncToggleLabel()
  }

  // Le libellé suit l'état des rayons. Rappelé après un rafraîchissement en
  // direct (turbo:morph) : le morph remet le texte du serveur, « Tout fermer »,
  // alors que les rayons repliés, eux, le restent.
  syncToggleLabel() {
    if (!this.hasToggleBtnTarget) return

    const allOpen = this.accordionControllers.every(c => c.openValue)
    this.toggleBtnTarget.textContent = allOpen ? "Tout fermer" : "Tout ouvrir"
  }
}
