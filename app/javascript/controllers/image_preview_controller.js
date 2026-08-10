import { Controller } from "@hotwired/stimulus"

// Zone de dépôt de la photo : glisser-déposer ou clic (le label ouvre le champ
// fichier), affichage du nom du fichier retenu, et bascule vers la zone de dépôt
// quand une photo déjà en place doit être remplacée.
export default class extends Controller {
  static targets = ["input", "notice", "uploadArea", "changeButton", "dropzone"]

  showFilename(event) {
    this.announce(event.target.files[0])
  }

  dragOver(event) {
    // Sans preventDefault, le navigateur ouvre le fichier au lieu de le déposer.
    event.preventDefault()
    this.dropzoneTarget.classList.add("is-dragging")
  }

  dragLeave() {
    this.dropzoneTarget.classList.remove("is-dragging")
  }

  dropFile(event) {
    event.preventDefault()
    this.dropzoneTarget.classList.remove("is-dragging")

    const file = event.dataTransfer.files[0]
    if (!file || !file.type.startsWith("image/")) return

    // Le champ fichier reste la seule source de vérité pour l'envoi du
    // formulaire : le fichier déposé doit y être réinjecté via un DataTransfer.
    const transfer = new DataTransfer()
    transfer.items.add(file)
    this.inputTarget.files = transfer.files

    this.announce(file)
  }

  // Affiche le champ de sélection et masque le bouton "changer de photo"
  showUploadField() {
    if (this.hasUploadAreaTarget) this.uploadAreaTarget.hidden = false
    if (this.hasChangeButtonTarget) this.changeButtonTarget.hidden = true
  }

  announce(file) {
    if (!file) return

    this.noticeTarget.textContent = `Tu as ajouté l'image : ${file.name}`
    this.noticeTarget.hidden = false
  }
}
