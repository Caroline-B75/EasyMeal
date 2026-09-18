import { Controller } from "@hotwired/stimulus"

// La pop-up « Mes habituelles » de la liste de courses (UC8, étape 3).
//
// Un <dialog> natif : showModal() piège le focus, Échap le ferme, et toucher le
// fond aussi. Son contenu est un turbo-frame rechargé à chaque ouverture : il
// dit toujours ce qui a déjà rejoint la liste.
//
// Le bouton d'envoi annonce combien d'articles partiront — ceux qui sont cochés
// avec une quantité —, et une ligne écartée s'estompe.
//
// Usage : posé sur la page de la liste de courses (menus/grocery.html.haml),
// autour du rappel, du bouton « Mes habituelles » et de la pop-up
// (usual_grocery_additions/_dialog.html.haml).
export default class extends Controller {
  static targets = ["dialog", "frame", "row", "submit"]
  static values = { url: String }

  open() {
    // Première ouverture : le frame reçoit son adresse et se charge. Ensuite,
    // il se recharge — un article a pu être ajouté depuis.
    if (this.frameTarget.src) {
      this.frameTarget.reload()
    } else {
      this.frameTarget.src = this.urlValue
    }
    this.dialogTarget.showModal()
  }

  close() {
    this.dialogTarget.close()
  }

  // Le fond d'un <dialog> modal, c'est le dialog lui-même : un clic qui le vise
  // directement est tombé hors de la carte.
  closeOnBackdrop(event) {
    if (event.target === this.dialogTarget) this.close()
  }

  // L'ajout a réussi : la liste se met à jour derrière, la pop-up s'efface.
  submitEnd(event) {
    if (event.detail.success) this.close()
  }

  checkAll() {
    this.setAll(true)
  }

  uncheckAll() {
    this.setAll(false)
  }

  setAll(checked) {
    this.rowTargets.forEach((row) => { row.querySelector("input[type=checkbox]").checked = checked })
    this.count()
  }

  // Les lignes et le bouton arrivent avec le frame : chacun recompte en entrant.
  rowTargetConnected() {
    this.count()
  }

  submitTargetConnected() {
    this.count()
  }

  count() {
    const chosen = this.rowTargets.filter((row) => {
      const kept = this.isChosen(row)
      row.classList.toggle("usual-picker-row--off", !kept)
      return kept
    }).length

    if (!this.hasSubmitTarget) return

    this.submitTarget.disabled = chosen === 0
    this.submitTarget.textContent = chosen === 0 ? "Ajouter" : `Ajouter ${chosen} article${chosen > 1 ? "s" : ""}`
  }

  isChosen(row) {
    const checkbox = row.querySelector("input[type=checkbox]")
    const quantity = row.querySelector("input[type=number]")
    return checkbox.checked && Number(quantity.value) > 0
  }
}
