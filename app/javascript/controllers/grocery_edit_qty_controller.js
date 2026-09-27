import { Controller } from "@hotwired/stimulus"

// Bascule entre affichage de la quantité et formulaire d'édition inline.
// L'état initial (masqué) est géré par CSS, pas par JS, pour éviter tout flash au chargement.
//
// La quantité se corrige dans l'unité choisie. Chaque option du sélecteur porte
// ce que la ligne vaut dans son unité (data-quantity, cf. grocery_quantity_edit_options) :
// changer d'unité y ramène le champ, sans aucun calcul ici.
export default class extends Controller {
  static targets = ["input", "unit"]

  edit() {
    this.element.classList.add("is-editing")
    this.inputTarget.focus()
    this.inputTarget.select()
  }

  // Rend au formulaire ses valeurs d'origine : rouvert, il repart de ce que
  // montre la ligne, et le morph ne le croit plus en cours de saisie.
  cancel() {
    this.inputTarget.value = this.inputTarget.defaultValue
    Array.from(this.unitTarget.options).forEach((option) => { option.selected = option.defaultSelected })
    this.element.classList.remove("is-editing")
  }

  changeUnit() {
    this.inputTarget.value = this.unitTarget.selectedOptions[0].dataset.quantity
    this.inputTarget.focus()
    this.inputTarget.select()
  }

  // Valider sans rien changer n'enregistre rien : en pièces, le champ montre
  // un compte arrondi (« 1 plaquette » pour 40 g), qui remplacerait la quantité
  // exacte de la recette.
  submit(event) {
    const option = this.unitTarget.selectedOptions[0]
    if (Number(this.inputTarget.value) !== Number(option.dataset.quantity)) return

    event.preventDefault()
    this.cancel()
  }

  handleKeydown(event) {
    if (event.key === "Escape") {
      event.preventDefault()
      this.cancel()
    }
  }
}
