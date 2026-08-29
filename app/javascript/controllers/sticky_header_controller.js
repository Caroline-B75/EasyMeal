// Publie la hauteur du header sticky en variable CSS (--header-height sur :root).
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    // La hauteur du header dépend du breakpoint (logo, paddings), de son contenu
    // et de la zone sûre iOS : elle n'est pas calculable en CSS. On la mesure et
    // on la publie sur :root, où la consomment les blocs qui doivent s'ancrer
    // sous le header (sidebars sticky des pages, scroll-padding des ancres).
    // ResizeObserver déclenche un premier callback dès l'observation : la valeur
    // est donc publiée au connect, puis suivie à chaque redimensionnement.
    this.observer = new ResizeObserver(() => this.publishHeight())
    this.observer.observe(this.element)
  }

  disconnect() {
    this.observer.disconnect()
  }

  publishHeight() {
    const height = Math.round(this.element.getBoundingClientRect().height)
    document.documentElement.style.setProperty("--header-height", `${height}px`)
  }
}
