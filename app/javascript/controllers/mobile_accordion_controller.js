import { Controller } from "@hotwired/stimulus"

// Replie un bloc en accordéon **sur mobile uniquement** : au-delà du point de
// rupture, le bloc est toujours déployé et son titre n'est pas un déclencheur.
//
// L'état est porté par une classe CSS sur l'élément du controller (et non par
// l'attribut `hidden` sur le contenu) pour deux raisons :
//   - le masquage reste sous contrôle du media query, donc un passage en
//     desktop ré-affiche le contenu sans que le JS ait à le rouvrir ;
//   - le controller peut vivre sur un ancêtre *hors* du fragment remplacé par
//     un Turbo Stream : l'état survit alors au re-render (voir le panneau de
//     réglages du menu, remplacé à chaque +/- du stepper).
//
// Cible :
//   toggle : le bouton qui plie / déplie (aria-expanded synchronisé)
// Valeurs :
//   query : media query où l'accordéon s'applique
//   open  : état initial sur mobile
export default class extends Controller {
  static targets = ["toggle"]
  static values = {
    query: { type: String, default: "(max-width: 1024px)" },
    open: { type: Boolean, default: false }
  }

  connect() {
    this.media = window.matchMedia(this.queryValue)
    this.syncMedia = () => this.#render()
    this.media.addEventListener("change", this.syncMedia)
    this.#render()
  }

  disconnect() {
    this.media.removeEventListener("change", this.syncMedia)
  }

  toggle() {
    this.openValue = !this.openValue
  }

  openValueChanged() {
    if (this.media) this.#render()
  }

  // Le fragment remplacé par un Turbo Stream revient dans son état serveur
  // (déployé) : on resynchronise le déclencheur dès qu'il reparaît.
  toggleTargetConnected() {
    if (this.media) this.#render()
  }

  #render() {
    const collapsible = this.media.matches
    const expanded = !collapsible || this.openValue

    this.element.classList.toggle("mobile-accordion--collapsed", !expanded)

    if (this.hasToggleTarget) {
      this.toggleTarget.disabled = !collapsible
      this.toggleTarget.setAttribute("aria-expanded", String(expanded))
    }
  }
}
