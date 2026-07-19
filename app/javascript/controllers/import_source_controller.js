import { Controller } from "@hotwired/stimulus"

// Gère le formulaire d'import IA :
//  - bascule accessible entre les onglets URL et Photo (aria-selected) ;
//  - aperçu de la photo sélectionnée avant envoi ;
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

  // Affiche un aperçu de la photo choisie et masque la zone de dépôt.
  previewPhoto(event) {
    const file = event.target.files[0]
    if (!file) {
      this.clearPhoto()
      return
    }

    const reader = new FileReader()
    reader.onload = (e) => {
      this.previewImgTarget.src = e.target.result
      this.previewNameTarget.textContent = file.name
      this.fileZoneTarget.hidden = true
      this.previewTarget.hidden = false
    }
    reader.readAsDataURL(file)
    this.clearError()
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

  // Vrai si la source active (URL ou photo) contient une valeur.
  hasSource() {
    if (this.sourceTypeTarget.value === "url") {
      return this.urlInputTarget.value.trim().length > 0
    }
    return this.fileInputTarget.files.length > 0
  }

  showError(message) {
    this.errorTarget.textContent = message
    this.errorTarget.hidden = false
  }
}
