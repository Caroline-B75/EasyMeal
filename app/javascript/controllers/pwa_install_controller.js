import { Controller } from "@hotwired/stimulus"
import { isInstallable, promptInstall } from "pwa_install"

// Révèle le point d'entrée « Installer l'application » uniquement quand le
// navigateur accepte réellement d'installer la PWA (site installable, pas déjà
// installé). Partout ailleurs l'élément reste masqué : mieux vaut aucun lien
// qu'un lien sans effet.
export default class extends Controller {
  connect() {
    this.onInstallable = () => this.toggle()
    this.onInstalled = () => { this.element.hidden = true }

    // L'événement peut avoir été capté avant cette connexion (chargement
    // initial) ou survenir après (navigation Turbo) : on couvre les deux cas.
    this.toggle()
    window.addEventListener("pwa:installable", this.onInstallable)
    window.addEventListener("pwa:installed", this.onInstalled)
  }

  disconnect() {
    window.removeEventListener("pwa:installable", this.onInstallable)
    window.removeEventListener("pwa:installed", this.onInstalled)
  }

  async install() {
    // L'événement natif ne se rejoue pas : le lien disparaît après usage et
    // réapparaîtra si le navigateur en émet un nouveau.
    this.element.hidden = true
    await promptInstall()
  }

  toggle() {
    this.element.hidden = !isInstallable()
  }
}
