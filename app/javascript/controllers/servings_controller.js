import { Controller } from "@hotwired/stimulus"
import { quantitySentence } from "quantities"

/**
 * Ajuste le nombre de personnes sur la fiche recette et remet les quantités à
 * l'échelle sans recharger la page.
 *
 * Ce contrôleur ne sait pas écrire une quantité : il lit ce que la ligne porte,
 * multiplie, et laisse le module quantities — miroir de Preparation#display_quantity
 * — en faire une phrase. C'est ce qui garantit qu'une ligne écrite par le
 * serveur au chargement garde la même forme après un clic.
 *
 * Usage :
 * <div data-controller="servings" data-servings-default-value="4">
 *   <button data-action="click->servings#decrease">−</button>
 *   <span data-servings-target="value">4</span>
 *   <button data-action="click->servings#increase">+</button>
 *
 *   <li data-servings-target="ingredient"
 *       data-base-quantity="400"
 *       data-unit-group="mass"
 *       data-default-servings="4"
 *       data-piece-label="pièce" data-piece-weight="300">
 *     <span data-servings-target="quantity">400 g</span>
 *   </li>
 * </div>
 */
export default class extends Controller {
  static targets = ["value", "ingredient", "quantity"]
  static values = { default: Number }

  connect() {
    this.servings = parseInt(this.valueTarget.textContent) || this.defaultValue || 4
  }

  /**
   * Augmente le nombre de personnes
   */
  increase(event) {
    event.preventDefault()
    this.servings += 1
    this.updateDisplay()
  }

  /**
   * Diminue le nombre de personnes (minimum 1)
   */
  decrease(event) {
    event.preventDefault()
    if (this.servings > 1) {
      this.servings -= 1
      this.updateDisplay()
    }
  }

  /**
   * Met à jour le compteur et recalcule chaque ingrédient
   */
  updateDisplay() {
    this.valueTarget.textContent = this.servings
    this.ingredientTargets.forEach(row => this.rescale(row))
  }

  /**
   * Réécrit la quantité d'une ligne pour le nombre de personnes courant.
   * Miroir de Preparation#scaled_quantity : la mise à l'échelle est un simple
   * facteur, tout le reste vit dans le module quantities.
   */
  rescale(row) {
    const baseQuantity = parseFloat(row.dataset.baseQuantity)
    const defaultServings = parseInt(row.dataset.defaultServings) || this.defaultValue
    const quantityElement = row.querySelector("[data-servings-target='quantity']")

    if (isNaN(baseQuantity) || !defaultServings || !quantityElement) return

    const scaled = baseQuantity * (this.servings / defaultServings)
    quantityElement.textContent = quantitySentence(scaled, this.ingredientOf(row))
  }

  /**
   * L'ingrédient réduit à ce qui sert à écrire sa quantité — mêmes noms que
   * partout ailleurs en JS (cf. units.js). Les attributs absents restent
   * undefined : un ingrédient sans nom de pièce se dit dans son unité.
   */
  ingredientOf({ dataset }) {
    return {
      unitGroup:   dataset.unitGroup,
      pieceLabel:  dataset.pieceLabel,
      piecePlural: dataset.piecePlural,
      pieceWeight: dataset.pieceWeight,
      pieceVolume: dataset.pieceVolume
    }
  }
}
