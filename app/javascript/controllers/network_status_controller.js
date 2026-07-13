import { Controller } from "@hotwired/stimulus"
import { replayQueue, pendingCount, QUEUE_CHANGED_EVENT } from "offline_queue"

/**
 * Indicateur GLOBAL et discret de l'état réseau (R0.3).
 *
 * - Affiche un bandeau « Hors ligne » dès que la connexion est perdue.
 * - Au retour en ligne (événement "online"), rejoue la file d'attente des
 *   toggles de la liste de courses et affiche « Synchronisation… » le temps
 *   de la synchro.
 *
 * Attaché sur un élément unique du layout, présent sur toutes les pages.
 */
export default class extends Controller {
  static targets = ["text"]

  connect() {
    // Références liées pour pouvoir les retirer proprement au disconnect.
    this.onOnline = this.handleOnline.bind(this)
    this.onOffline = () => this.render()
    this.onQueueChanged = () => this.render()

    window.addEventListener("online", this.onOnline)
    window.addEventListener("offline", this.onOffline)
    document.addEventListener(QUEUE_CHANGED_EVENT, this.onQueueChanged)

    this.syncing = false
    this.render()

    // Cas d'un retour dans l'app déjà en ligne avec des toggles en attente
    // (ex : page rouverte après avoir été fermée hors-ligne) : on synchronise.
    if (navigator.onLine && pendingCount() > 0) this.handleOnline()
  }

  disconnect() {
    window.removeEventListener("online", this.onOnline)
    window.removeEventListener("offline", this.onOffline)
    document.removeEventListener(QUEUE_CHANGED_EVENT, this.onQueueChanged)
  }

  async handleOnline() {
    if (pendingCount() > 0) {
      this.syncing = true
      this.render()
      await replayQueue()
      this.syncing = false
    }
    this.render()
  }

  // Met à jour le libellé et les classes d'état selon la connexion et la synchro.
  render() {
    const offline = !navigator.onLine
    const syncing = this.syncing && pendingCount() > 0

    this.element.classList.toggle("network-status--offline", offline)
    this.element.classList.toggle("network-status--syncing", !offline && syncing)
    this.element.classList.toggle(
      "network-status--visible",
      offline || (!offline && syncing)
    )

    if (this.hasTextTarget) {
      if (offline) {
        this.textTarget.textContent = "Hors ligne"
      } else if (syncing) {
        this.textTarget.textContent = "Synchronisation…"
      }
    }
  }
}
