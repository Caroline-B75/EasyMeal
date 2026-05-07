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
    if (allOpen) {
      this.accordionControllers.forEach(c => c.close())
      if (this.hasToggleBtnTarget) this.toggleBtnTarget.textContent = "Tout ouvrir"
    } else {
      this.accordionControllers.forEach(c => c.open())
      if (this.hasToggleBtnTarget) this.toggleBtnTarget.textContent = "Tout fermer"
    }
  }
}
