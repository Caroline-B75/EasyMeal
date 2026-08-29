import { Controller } from "@hotwired/stimulus"

// Liste des vignettes du rail « menu à valider » (catalogue de recettes).
// Les recettes sont empilées dans l'ordre du menu : la dernière ajoutée est donc
// en fin de liste, hors champ dès que le menu dépasse la hauteur (desktop) ou la
// largeur (mobile) du rail. Le fragment étant remplacé par Turbo Stream à chaque
// ajout, un défilement au connect() suffit à amener la nouvelle vignette à vue.
// Les deux axes sont poussés : un seul est défilable selon le breakpoint,
// l'autre est un no-op.
export default class extends Controller {
  connect() {
    this.element.scrollTop = this.element.scrollHeight
    this.element.scrollLeft = this.element.scrollWidth
  }
}
