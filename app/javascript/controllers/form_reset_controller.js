import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  reset({ detail: { success } }) {
    if (success) this.element.reset()
  }
}
