import { Controller } from "@hotwired/stimulus"

// Éditeur d'une course habituelle (page « Courses habituelles », UC8 étape 3).
//
// La pastille de quantité l'ouvre ; Échap, un clic ailleurs ou le fond le
// referment. Le même balisage se présente dans la ligne sur grand écran et en
// panneau montant du bas sur mobile : c'est la feuille de style qui en décide
// (.usual-item--editing, grocery_items.css), pas ce contrôleur.
//
// Enregistrer renvoie la page à jour (morph) : l'éditeur y revient fermé.
//
// Usage : cf. households/usual_grocery_items/_usual_grocery_item.html.haml
export default class extends Controller {
  static targets = ["panel", "pill", "input"]

  open() {
    this.panelTarget.hidden = false
    this.element.classList.add("usual-item--editing")
    this.pillTarget.setAttribute("aria-expanded", "true")

    // Sur grand écran, le curseur file dans la quantité. Pas sur mobile : le
    // clavier recouvrirait le panneau avant qu'on ait vu ses boutons − / +.
    if (window.matchMedia("(min-width: 768px)").matches) this.inputTarget.select()
  }

  close() {
    if (this.panelTarget.hidden) return

    this.panelTarget.hidden = true
    this.element.classList.remove("usual-item--editing")
    this.pillTarget.setAttribute("aria-expanded", "false")
  }

  closeOnOutsideClick(event) {
    if (!this.element.contains(event.target)) this.close()
  }
}
