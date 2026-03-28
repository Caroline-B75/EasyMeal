import { Controller } from "@hotwired/stimulus"

// Affiche le nom de l'image sélectionnée sous le bouton d'upload
// et gère l'affichage du champ de remplacement de photo
export default class extends Controller {
  static targets = ["input", "notice", "uploadArea", "changeButton"]

  showFilename(event) {
    const file = event.target.files[0]
    if (!file) return

    this.noticeTarget.textContent = `Tu as ajouté l'image : ${file.name}`
    this.noticeTarget.hidden = false
  }

  // Affiche le champ de sélection et masque le bouton "changer de photo"
  showUploadField() {
    if (this.hasUploadAreaTarget) this.uploadAreaTarget.hidden = false
    if (this.hasChangeButtonTarget) this.changeButtonTarget.hidden = true
  }
}
