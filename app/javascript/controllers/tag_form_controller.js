import { Controller } from "@hotwired/stimulus"

// Redonne le focus au champ nom après une création réussie (ajout à la volée).
// Le controller n'est attaché que dans la réponse Turbo Stream de création :
// au chargement initial de la page, il est absent et ne vole donc pas le focus.
export default class extends Controller {
  static targets = ["input"]

  connect() {
    if (this.hasInputTarget) this.inputTarget.focus()
  }
}
