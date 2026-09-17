import { Controller } from "@hotwired/stimulus"

/**
 * Rattrape ce qu'une coupure a fait manquer. Les mises à jour en direct
 * (turbo_stream_from) ne sont pas rejouées : pendant que le réseau manquait, ou
 * que le téléphone dormait, les coches des autres membres du foyer sont passées
 * sans laisser de trace. Dès que l'abonnement se rétablit, la page se
 * rafraîchit (morph, défilement conservé).
 *
 * Turbo signale l'état de l'abonnement par l'attribut « connected » de
 * <turbo-cable-stream-source>. La première connexion ne déclenche rien : la
 * page vient d'être servie, elle est à jour.
 *
 * Usage :
 *   %div{ data: { controller: "live-refresh" } }
 *     = turbo_stream_from(...)
 */
export default class extends Controller {
  connect() {
    this.source = this.element.querySelector("turbo-cable-stream-source")
    if (!this.source) return

    this.connectedOnce = this.source.hasAttribute("connected")
    this.connectionLost = false
    this.observer = new MutationObserver(() => this.connectionChanged())
    this.observer.observe(this.source, { attributes: true, attributeFilter: ["connected"] })
  }

  disconnect() {
    this.observer?.disconnect()
  }

  connectionChanged() {
    if (!this.source.hasAttribute("connected")) {
      this.connectionLost = this.connectedOnce
      return
    }

    this.connectedOnce = true
    if (!this.connectionLost) return

    this.connectionLost = false
    window.Turbo.visit(window.location.href, { action: "replace" })
  }
}
