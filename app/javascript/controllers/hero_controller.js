import { Controller } from "@hotwired/stimulus"

// Controller pour ajuster dynamiquement la hauteur du hero en fonction du header
export default class extends Controller {
  connect() {
    this.adjustHeight()
    
    // Réajuster lors du redimensionnement de la fenêtre
    this.resizeObserver = new ResizeObserver(() => {
      this.adjustHeight()
    })
    
    // Observer le header pour détecter les changements de taille
    const header = document.querySelector('.main-header')
    if (header) {
      this.resizeObserver.observe(header)
    }
    
    // Réajuster aussi lors du redimensionnement de la fenêtre
    window.addEventListener('resize', this.handleResize.bind(this))
  }

  disconnect() {
    if (this.resizeObserver) {
      this.resizeObserver.disconnect()
    }
    window.removeEventListener('resize', this.handleResize.bind(this))
  }

  handleResize() {
    this.adjustHeight()
  }

  adjustHeight() {
    const header = document.querySelector('.main-header')
    if (header) {
      const headerHeight = header.offsetHeight
      // Appliquer la hauteur calculée au hero-section
      this.element.style.height = `calc(100vh - ${headerHeight}px)`
    }
  }
}
