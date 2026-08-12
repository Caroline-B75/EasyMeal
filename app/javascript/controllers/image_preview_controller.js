import { Controller } from "@hotwired/stimulus"
import { assignFile, acceptsFile, clipboardImage, readImageUrl } from "photo_input"

// Zone de dépôt de la photo. Trois façons de choisir un fichier — clic (la zone
// est le label du champ), glisser-déposer, collage d'une capture d'écran
// n'importe où sur la page — qui aboutissent toutes à la même vignette et au
// même message. Gère aussi la bascule vers la zone de dépôt quand une photo
// déjà en place doit être remplacée.
export default class extends Controller {
  static targets = ["input", "notice", "uploadArea", "changeButton", "dropzone", "preview"]

  // Sélection au clic : le fichier est déjà dans le champ.
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

  // Fichier venu d'un dépôt ou d'un collage : il n'entre dans le formulaire
  // qu'une fois réinjecté dans le champ fichier.
  adopt(file) {
    // Ces deux gestes contournent le filtre du sélecteur natif : sans ce mot,
    // déposer un PDF donnerait l'impression que rien ne s'est passé.
    if (!acceptsFile(this.inputTarget, file)) {
      this.previewTarget.hidden = true
      this.notify("Ce fichier n'est pas une image : choisis un JPEG ou un PNG.")
      return
    }

    assignFile(this.inputTarget, file)
    this.announce(file)
  }

  announce(file) {
    if (!file) return

    this.showPreview(file)
    this.notify(`Tu as ajouté l'image : ${file.name}`)
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
