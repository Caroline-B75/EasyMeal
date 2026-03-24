import { Controller } from "@hotwired/stimulus"

// Affiche le nom de l'image sélectionnée sous le bouton d'upload
export default class extends Controller {
  static targets = ["input", "notice"]

  showFilename(event) {
    const file = event.target.files[0]
    if (!file) return

    this.noticeTarget.textContent = `Tu as ajouté l'image : ${file.name}`
    this.noticeTarget.hidden = false
  }
}
