import { Controller } from "@hotwired/stimulus"
import { acceptPhoto, clipboardImage, readImageUrl } from "photo_input"

// Zone de dépôt de la photo. Trois façons de choisir un fichier — clic (la zone
// est le label du champ), glisser-déposer, collage d'une capture d'écran
// n'importe où sur la page — qui aboutissent toutes au même contrôle, à la même
// réduction, à la même vignette et au même message. Gère aussi la bascule vers
// la zone de dépôt quand une photo déjà en place doit être remplacée.
export default class extends Controller {
  static targets = ["input", "notice", "uploadArea", "changeButton", "dropzone", "preview"]

  // Sélection au clic : le fichier est déjà dans le champ, mais il doit passer
  // par le même contrôle que les deux autres gestes — le sélecteur natif filtre
  // les formats, pas le poids ni la définition.
  showFilename(event) {
    this.adopt(event.target.files[0])
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

    this.adopt(event.dataTransfer.files[0])
  }

  // Collage n'importe où sur la page : une capture d'écran devient la photo de
  // la recette. L'action `paste@document` est détachée par Stimulus à la
  // déconnexion du contrôleur.
  paste(event) {
    const image = clipboardImage(event)
    if (!image) return

    event.preventDefault()
    // Une photo déjà en place masque la zone d'upload : sans la révéler, ni la
    // vignette ni le message du fichier collé ne seraient visibles.
    this.showUploadField()
    this.adopt(image)
  }

  // Affiche le champ de sélection et masque le bouton "changer de photo"
  showUploadField() {
    if (this.hasUploadAreaTarget) this.uploadAreaTarget.hidden = false
    if (this.hasChangeButtonTarget) this.changeButtonTarget.hidden = true
  }

  // Passage obligé des trois gestes : le fichier entre dans le champ, puis y est
  // remplacé par sa version réduite. La vignette et le message n'annoncent que
  // ce fichier-là — celui qui partira vraiment.
  adopt(file) {
    if (!file) return

    const rejection = acceptPhoto(this.inputTarget, file, (photo) => this.announce(photo))
    if (!rejection) return

    this.previewTarget.hidden = true
    this.notify(rejection)
  }

  // Photo retrouvée par form-recovery après un rechargement : elle est déjà dans
  // le champ, elle n'a ni à repasser le contrôle ni à être réduite — seule sa
  // mise en scène est à refaire, zone de dépôt comprise (une recette qui a déjà
  // une photo la garde masquée).
  restored() {
    const file = this.inputTarget.files[0]
    if (!file) return

    this.showUploadField()
    this.announce(file)
  }

  // Le fichier réellement retenu, réduction faite. C'est le seul moment où une
  // photo est bonne à retenir ailleurs : avant, le champ porte encore
  // l'originale, qui sort d'un téléphone.
  announce(file) {
    this.showPreview(file)
    this.notify(`Tu as ajouté l'image : ${file.name}`)
    this.dispatch("ready", { detail: { file: file } })
  }

  // Vignette du fichier retenu : le nom d'une capture collée ("image.png") ne
  // dit rien, seule l'image confirme ce qui sera envoyé.
  showPreview(file) {
    readImageUrl(file).then((url) => {
      if (!url) return

      this.previewTarget.src = url
      this.previewTarget.hidden = false
    })
  }

  notify(message) {
    this.noticeTarget.textContent = message
    this.noticeTarget.hidden = false
  }
}
