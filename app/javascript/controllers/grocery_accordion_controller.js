import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["body", "chevron"]
  static values = { open: { type: Boolean, default: true } }

  toggle() {
    this.openValue = !this.openValue
  }

  open() {
    this.openValue = true
  }

  close() {
    this.openValue = false
  }

  openValueChanged() {
    if (this.hasBodyTarget) {
      this.bodyTarget.hidden = !this.openValue
    }
    if (this.hasChevronTarget) {
      this.chevronTarget.classList.toggle("grocery-section-chevron--closed", !this.openValue)
    }
  }
}
