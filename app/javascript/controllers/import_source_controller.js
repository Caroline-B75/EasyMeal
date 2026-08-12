import { Controller } from "@hotwired/stimulus"
import { assignFile, acceptsFile, clipboardImage, readImageUrl } from "photo_input"

// Un texte collé n'est pris pour une adresse de recette que s'il ressemble à une
// URL complète, d'un seul tenant : sinon on laisse le collage au navigateur.
const HTTP_URL = /^https?:\/\/\S+$/i

// Dépôt et collage n'ont pas le filtre du sélecteur natif : il faut le refuser
// nous-mêmes, plutôt que d'envoyer un format que l'IA ne saura pas lire.
const UNSUPPORTED_FILE_ERROR = "Format non accepté : choisis une image JPG, PNG ou WebP."

// Gère le formulaire d'import IA :
//  - bascule accessible entre les onglets URL et Photo (aria-selected) ;
//  - trois chemins d'entrée pour la photo — clic, glisser-déposer, collage —
//    qui convergent tous vers le champ fichier puis l'aperçu ;
//  - collage n'importe où sur la page : une image ouvre l'onglet Photo, une URL
//    ouvre l'onglet Lien (l'action `paste@document` est détachée par Stimulus
//    à la déconnexion du contrôleur) ;
//  - garde anti-envoi à vide + état de chargement visible (spinner) au submit.
export default class extends Controller {
  static targets = [
    "urlSection", "photoSection", "sourceType", "urlTab", "photoTab",
    "urlInput", "fileInput", "fileZone", "preview", "previewImg", "previewName",
    "submitBtn", "submitLabel", "spinner", "error"
  ]

  selectUrl() {
    this.activateTab("url")
  }

  selectPhoto() {
    this.activateTab("photo")
  }

  // Sélection au clic : le fichier est déjà dans le champ, seul l'aperçu manque.
  previewPhoto(event) {
    const file = event.target.files[0]
    if (!file) {
      this.clearPhoto()
      return
    }

    this.showPreview(file)
  }

  dragOver(event) {
    // Sans preventDefault, le navigateur ouvre le fichier au lieu de le déposer.
    event.preventDefault()
    this.fileZoneTarget.classList.add("is-dragging")
  }

  dragLeave(event) {
    // Passer du champ fichier à sa bordure émet un dragleave parasite : l'état
    // ne retombe que si le curseur quitte vraiment la zone.
    if (this.fileZoneTarget.contains(event.relatedTarget)) return

    this.fileZoneTarget.classList.remove("is-dragging")
  }

  dropPhoto(event) {
    event.preventDefault()
    this.fileZoneTarget.classList.remove("is-dragging")

    // Sans ce mot, déposer un PDF donnerait l'impression que rien ne s'est passé.
    if (!this.adoptPhoto(event.dataTransfer.files[0])) {
      this.showError(UNSUPPORTED_FILE_ERROR)
    }
  }

  // Collage global : le presse-papiers dicte l'onglet à ouvrir.
  paste(event) {
    const clipboard = event.clipboardData
    if (!clipboard) return

    // Une image collée n'a de sens nulle part ailleurs : on la prend même si le
    // curseur est dans le champ URL, où elle ne collerait rien.
    const image = clipboardImage(event)
    if (image) {
      event.preventDefault()
      this.activateTab("photo")
      if (!this.adoptPhoto(image)) this.showError(UNSUPPORTED_FILE_ERROR)
      return
    }

    // Un texte collé dans un champ de saisie appartient à ce champ.
    if (this.isEditable(event.target)) return

    const text = clipboard.getData("text").trim()
    if (!HTTP_URL.test(text)) return

    event.preventDefault()
    this.activateTab("url")
    this.urlInputTarget.value = text
    this.urlInputTarget.focus()
  }

  // Réinitialise la sélection de photo et réaffiche la zone de dépôt.
  clearPhoto() {
    this.fileInputTarget.value = ""
    this.previewImgTarget.removeAttribute("src")
    this.previewTarget.hidden = true
    this.fileZoneTarget.hidden = false
  }

  clearError() {
    this.errorTarget.hidden = true
    this.errorTarget.textContent = ""
  }

  // Bloque l'envoi si la source est vide (évite une attente inutile de 15-30 s),
  // sinon affiche l'état de chargement et empêche les double-clics.
  submit(event) {
    if (!this.hasSource()) {
      event.preventDefault()
      this.showError(
        this.sourceTypeTarget.value === "url"
          ? "Saisis l'URL d'une recette à importer."
          : "Choisis une photo de recette à importer."
      )
      return
    }

    this.submitBtnTarget.disabled = true
    this.spinnerTarget.hidden = false
    this.submitLabelTarget.textContent = "Extraction en cours… (15 à 30 s)"
  }

  // Bascule l'onglet actif et met à jour l'état ARIA + les sections visibles.
  activateTab(type) {
    const isUrl = type === "url"
    this.sourceTypeTarget.value = type

    this.urlSectionTarget.hidden = !isUrl
    this.photoSectionTarget.hidden = isUrl

    this.urlTabTarget.classList.toggle("import-tab--active", isUrl)
    this.photoTabTarget.classList.toggle("import-tab--active", !isUrl)
    this.urlTabTarget.setAttribute("aria-selected", String(isUrl))
    this.photoTabTarget.setAttribute("aria-selected", String(!isUrl))

    this.clearError()
  }

  // Fichier venu d'un dépôt ou d'un collage : il n'entre dans le formulaire
  // qu'une fois réinjecté dans le champ fichier. Retourne false si le format
  // n'est pas accepté.
  adoptPhoto(file) {
    if (!acceptsFile(this.fileInputTarget, file)) return false

    assignFile(this.fileInputTarget, file)
    this.showPreview(file)
    return true
  }

  // Aperçu commun aux trois chemins d'entrée : vignette, nom, zone de dépôt
  // masquée le temps que la photo tienne la place.
  showPreview(file) {
    readImageUrl(file).then((url) => {
      if (!url) return

      this.previewImgTarget.src = url
      this.previewNameTarget.textContent = file.name
      this.fileZoneTarget.hidden = true
      this.previewTarget.hidden = false
    })
    this.clearError()
  }

  // Vrai si la source active (URL ou photo) contient une valeur.
  hasSource() {
    if (this.sourceTypeTarget.value === "url") {
      return this.urlInputTarget.value.trim().length > 0
    }
    return this.fileInputTarget.files.length > 0
  }

  isEditable(element) {
    return element instanceof HTMLElement &&
      (element.isContentEditable || ["INPUT", "TEXTAREA", "SELECT"].includes(element.tagName))
  }

  showError(message) {
    this.errorTarget.textContent = message
    this.errorTarget.hidden = false
  }
}
