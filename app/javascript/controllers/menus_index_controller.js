import { Controller } from "@hotwired/stimulus"

// Gère les interactions de la page index des menus :
// - Expand/collapse des cartes d'historique
// - Afficher/masquer les menus plus anciens
export default class extends Controller {
  static targets = ["olderMenus", "toggleOlderBtn", "toggleOlderText"]

  // Toggle l'expansion d'une carte historique (détails + recettes)
  toggleHistory(event) {
    const card = event.currentTarget.closest(".mi-history-card")
    if (!card) return

    const expanded = card.querySelector(".mi-history-expanded")
    const icon = event.currentTarget.querySelector(".mi-expand-icon")
    if (!expanded || !icon) return

    const isOpen = expanded.classList.contains("open")
    expanded.classList.toggle("open", !isOpen)
    icon.classList.toggle("open", !isOpen)
  }

  // Afficher/masquer les menus plus anciens
  toggleOlder() {
    const isVisible = this.olderMenusTarget.classList.contains("open")

    this.olderMenusTarget.classList.toggle("open", !isVisible)

    // Toggle l'icône chevron dans le bouton
    const icon = this.toggleOlderBtnTarget.querySelector(".mi-toggle-old-icon")
    if (icon) {
      icon.classList.toggle("open", !isVisible)
    }

    const count = this.olderMenusTarget.dataset.count
    this.toggleOlderTextTarget.textContent = isVisible
      ? `Afficher ${count} menus plus anciens`
      : "Masquer les menus plus anciens"
  }
}
