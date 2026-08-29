import { Controller } from "@hotwired/stimulus"
import { assignFile, acceptsFile, clipboardImage, readImageUrl } from "photo_input"
import { downscaleImage } from "image_downscale"

// Un texte collé n'est pris pour une adresse de recette que s'il ressemble à une
// URL complète, d'un seul tenant : sinon on laisse le collage au navigateur.
const HTTP_URL = /^https?:\/\/\S+$/i

// Dépôt et collage n'ont pas le filtre du sélecteur natif : il faut le refuser
// nous-mêmes, plutôt que d'envoyer un format que l'IA ne saura pas lire.
const UNSUPPORTED_FILE_ERROR = "Format non accepté : choisis une image JPG, PNG ou WebP."

// Garde-fou dur, appliqué au fichier choisi : la réduction ci-dessous est une
// optimisation qui peut échouer, et un fichier de cette taille ne doit jamais
// partir vers le serveur, réduit ou non.
const MAX_FILE_BYTES = 20 * 1024 * 1024
const OVERSIZED_FILE_ERROR = "Photo trop lourde (20 Mo maximum) : choisis une image plus légère."

// Ce que dit le bouton une fois cliqué. L'envoi ne dure plus que le temps de
// déposer la commande — et, pour une photo, de la téléverser : l'extraction se
// suit ensuite sur la page d'attente, qui annonce ses propres étapes.
const SUBMIT_LABEL = "Envoi en cours…"

// Poids lisible du fichier qui partira vraiment : c'est la réassurance que la
// réduction a bien eu lieu. Base 1000, comme l'explorateur de fichiers.
function formatFileSize(bytes) {
  if (bytes >= 1000000) return `${(bytes / 1000000).toFixed(1)} Mo`

  return `${Math.max(1, Math.round(bytes / 1000))} Ko`
}

// Gère le formulaire d'import IA :
//  - bascule accessible entre les onglets URL et Photo (aria-selected) ;
//  - trois chemins d'entrée pour la photo — clic, glisser-déposer, collage —
//    qui convergent tous vers adoptPhoto : filtre, réduction, aperçu ;
//  - collage n'importe où sur la page : une image ouvre l'onglet Photo, une URL
//    ouvre l'onglet Lien (l'action `paste@document` est détachée par Stimulus
//    à la déconnexion du contrôleur) ;
//  - garde anti-envoi à vide + attente habitée au submit (spinner et messages
//    d'étape qui défilent).
export default class extends Controller {
  static targets = [
    "urlSection", "photoSection", "sourceType", "urlTab", "photoTab",
    "urlInput", "fileInput", "fileZone", "preview", "previewImg", "previewName",
    "previewSize", "submitBtn", "submitLabel", "spinner", "error"
  ]


  selectUrl() {
    this.activateTab("url")
  }

  selectPhoto() {
    this.activateTab("photo")
  }

  // Sélection au clic : le fichier est déjà dans le champ, mais il doit passer
  // par le même filtre et la même réduction que le dépôt et le collage.
  previewPhoto(event) {
    const file = event.target.files[0]
    if (!file) {
      this.clearPhoto()
      return
    }

    // Un fichier refusé est déjà dans le champ : il faut l'en retirer.
    if (!this.adoptPhoto(file)) this.clearPhoto()
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

    this.adoptPhoto(event.dataTransfer.files[0])
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
      this.adoptPhoto(image)
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
    this.pendingPhoto = null
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
    this.submitLabelTarget.textContent = SUBMIT_LABEL
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

  // Passage obligé des trois chemins d'entrée : contrôle du fichier, puis
  // réduction avant de le confier au champ. Retourne false si le fichier est
  // refusé — l'aperçu, lui, attend la fin de la réduction.
  adoptPhoto(file) {
    // Dépôt et collage contournent le filtre du sélecteur natif : sans ce mot,
    // déposer un PDF donnerait l'impression que rien ne s'est passé.
    if (!acceptsFile(this.fileInputTarget, file)) {
      this.showError(UNSUPPORTED_FILE_ERROR)
      return false
    }

    if (file.size > MAX_FILE_BYTES) {
      this.showError(OVERSIZED_FILE_ERROR)
      return false
    }

    // Le champ reçoit d'abord l'original : la réduction est asynchrone, et un
    // envoi lancé entre-temps doit partir avec la photo brute plutôt qu'à vide.
    assignFile(this.fileInputTarget, file)
    this.pendingPhoto = file

    downscaleImage(file).then((photo) => {
      // Photo retirée ou remplacée pendant la réduction : ce résultat est périmé.
      if (this.pendingPhoto !== file) return

      assignFile(this.fileInputTarget, photo)
      this.showPreview(photo)
    })
    return true
  }

  // Aperçu commun aux trois chemins d'entrée : vignette, nom et poids du fichier
  // réellement envoyé, zone de dépôt masquée le temps que la photo tienne la place.
  showPreview(file) {
    readImageUrl(file).then((url) => {
      if (!url) return

      this.previewImgTarget.src = url
      this.previewNameTarget.textContent = file.name
      this.previewSizeTarget.textContent = formatFileSize(file.size)
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
