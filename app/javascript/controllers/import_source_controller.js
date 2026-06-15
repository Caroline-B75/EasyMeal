import { Controller } from "@hotwired/stimulus"

// Gère le formulaire d'import IA : bascule entre les onglets URL et Photo,
// et affiche un indicateur de chargement pendant l'extraction.
export default class extends Controller {
  static targets = ["urlSection", "photoSection", "sourceType", "urlTab", "photoTab", "submitBtn"]

  selectUrl() {
    this.sourceTypeTarget.value = "url"
    this.urlSectionTarget.hidden = false
    this.photoSectionTarget.hidden = true
    this.urlTabTarget.classList.add("import-tab--active")
    this.photoTabTarget.classList.remove("import-tab--active")
  }

  selectPhoto() {
    this.sourceTypeTarget.value = "photo"
    this.urlSectionTarget.hidden = true
    this.photoSectionTarget.hidden = false
    this.urlTabTarget.classList.remove("import-tab--active")
    this.photoTabTarget.classList.add("import-tab--active")
  }

  submit() {
    const btn = this.submitBtnTarget
    btn.disabled = true
    btn.value = "Extraction en cours… (15-30 secondes)"
  }
}
