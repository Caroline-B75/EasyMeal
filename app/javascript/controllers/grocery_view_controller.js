import { Controller } from "@hotwired/stimulus"

// Réglages valables pour l'onglet : ils survivent aux rafraîchissements et aux
// Turbo Streams qui remplacent la liste, mais l'application rouverte repart en
// mode Courses, sans filtre — personne ne retrouve une liste à moitié cachée.
const STORAGE_KEY = "easymeal.groceryView"

/**
 * Affichage d'une liste de courses partagée par le foyer (« Je m'en occupe ») :
 *   - le mode : « Courses », on coche ; « Répartir », on prend ou on laisse ;
 *   - le filtre « Ma part » : mes articles et ceux que personne n'a pris.
 *
 * Tout passe par la CSS, d'après les valeurs posées sur la liste
 * (data-grocery-view-mode-value, data-grocery-view-mine-value) : aucun
 * aller-retour serveur, donc les deux marchent hors ligne, au fond du magasin.
 * Un rafraîchissement en direct ne les efface pas (data-morph-keep).
 */
export default class extends Controller {
  static targets = ["modeButton", "mineButton"]
  static values = {
    mode: { type: String, default: "courses" },
    mine: Boolean
  }

  connect() {
    const saved = this.read()
    if (saved.mode) this.modeValue = saved.mode
    if (typeof saved.mine === "boolean") this.mineValue = saved.mine
  }

  setMode({ params: { mode } }) {
    this.modeValue = mode
    // Répartir, c'est voir toute la liste : le filtre ne survit pas au changement de mode
    this.mineValue = false
    this.save()
  }

  toggleMine() {
    this.mineValue = !this.mineValue
    this.save()
  }

  modeValueChanged() {
    this.modeButtonTargets.forEach((button) => {
      button.setAttribute("aria-pressed", String(button.dataset.groceryViewModeParam === this.modeValue))
    })
  }

  mineValueChanged() {
    this.mineButtonTargets.forEach((button) => button.setAttribute("aria-pressed", String(this.mineValue)))
  }

  read() {
    try {
      return JSON.parse(sessionStorage.getItem(STORAGE_KEY)) || {}
    } catch {
      // Stockage bloqué ou valeur corrompue : l'affichage par défaut fait l'affaire.
      return {}
    }
  }

  save() {
    try {
      sessionStorage.setItem(STORAGE_KEY, JSON.stringify({ mode: this.modeValue, mine: this.mineValue }))
    } catch {
      // Stockage indisponible : le réglage vaut jusqu'au prochain remplacement de la liste.
    }
  }
}
