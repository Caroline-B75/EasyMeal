import { Controller } from "@hotwired/stimulus"

// Gère l'auto-hide des messages flash après 4 secondes
export default class extends Controller {
  static values = {
    delay: { type: Number, default: 4000 }
  }

  connect() {
    this.timeout = setTimeout(() => {
      this.hide()
    }, this.delayValue)
  }

  disconnect() {
    if (this.timeout) {
      clearTimeout(this.timeout)
    }
  }

  hide() {
    this.element.style.transition = 'opacity 0.5s ease-out, transform 0.5s ease-out'
    this.element.style.opacity = '0'
    this.element.style.transform = 'translateX(100%)'
    
    setTimeout(() => {
      this.element.remove()
    }, 500)
  }

  // Permet de fermer manuellement en cliquant
  close() {
    if (this.timeout) {
      clearTimeout(this.timeout)
    }
    this.hide()
  }
}
