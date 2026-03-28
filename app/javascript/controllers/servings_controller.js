import { Controller } from "@hotwired/stimulus"

/**
 * Controller pour ajuster le nombre de personnes sur la fiche recette
 * Recalcule les quantités d'ingrédients en temps réel avec conversions d'unités
 * 
 * Conversions gérées :
 * - mass: g → kg (à partir de 1000g)
 * - volume: ml → L (à partir de 1000ml)
 * - spoon: càc → càs (3 càc = 1 càs), pincées pour < 0.5 càc
 * - count: affichage direct du nombre
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
 *       data-default-servings="4">
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
   * Met à jour l'affichage et recalcule les quantités
   */
  updateDisplay() {
    // Met à jour le compteur
    this.valueTarget.textContent = this.servings

    // Recalcule chaque ingrédient
    this.ingredientTargets.forEach(ingredient => {
      const baseQuantity = parseFloat(ingredient.dataset.baseQuantity)
      const defaultServings = parseInt(ingredient.dataset.defaultServings) || this.defaultValue
      const unitGroup = ingredient.dataset.unitGroup || "count"
      
      if (isNaN(baseQuantity) || isNaN(defaultServings)) return
      
      // Calcul du facteur et de la nouvelle quantité
      const factor = this.servings / defaultServings
      const newQuantity = baseQuantity * factor
      
      // Trouve l'élément quantity dans cet ingrédient
      const quantityElement = ingredient.querySelector("[data-servings-target='quantity']")
      
      if (quantityElement) {
        // Applique l'humanisation selon le groupe d'unités
        quantityElement.textContent = this.humanizeQuantity(newQuantity, unitGroup)
      }
    })
  }

  // === HUMANISATION DES QUANTITÉS ===
  // Reproduit la logique de Quantities::HumanizeService en JavaScript

  /**
   * Convertit une quantité brute en affichage lisible
   * @param {number} quantity - Quantité en unité de base
   * @param {string} unitGroup - Type d'unité (mass, volume, spoon, count)
   * @returns {string} Quantité formatée avec unité
   */
  humanizeQuantity(quantity, unitGroup) {
    switch (unitGroup) {
      case "mass":
        return this.humanizeMass(quantity)
      case "volume":
        return this.humanizeVolume(quantity)
      case "spoon":
        return this.humanizeSpoon(quantity)
      case "count":
        return this.humanizeCount(quantity)
      default:
        return this.formatNumber(quantity)
    }
  }

  /**
   * Humanise les masses (g → kg)
   */
  humanizeMass(quantity) {
    if (quantity >= 1000) {
      const kg = quantity / 1000
      return `${this.formatNumber(kg)} kg`
    }
    return `${this.formatNumber(quantity)} g`
  }

  /**
   * Humanise les volumes (ml → L)
   */
  humanizeVolume(quantity) {
    if (quantity >= 1000) {
      const liters = quantity / 1000
      return `${this.formatNumber(liters)} L`
    }
    return `${this.formatNumber(quantity)} ml`
  }

  /**
   * Humanise les cuillères (càc → càs, pincées)
   * 3 càc = 1 càs | 0.25 càc = 1 pincée
   */
  humanizeSpoon(quantity) {
    // Pincées pour très petites quantités (< 0.5 càc)
    if (quantity < 0.5) {
      const pinches = Math.round(quantity / 0.25)
      if (pinches <= 1) {
        return "1 pincée"
      }
      return `${pinches} pincées`
    }

    // Conversion en càs si >= 3 càc
    if (quantity >= 3) {
      const tablespoons = quantity / 3
      return `${this.formatNumber(tablespoons)} càs`
    }

    // Sinon càc
    return `${this.formatNumber(quantity)} càc`
  }

  /**
   * Humanise les comptages (pièces)
   */
  humanizeCount(quantity) {
    // Arrondit intelligemment les comptages
    // Garde les demi-unités, arrondit le reste
    const rounded = Math.round(quantity * 2) / 2
    return this.formatNumber(rounded)
  }

  /**
   * Formate un nombre avec virgule française et suppression des décimales inutiles
   * @param {number} num - Nombre à formater
   * @returns {string} Nombre formaté
   */
  formatNumber(num) {
    // Arrondit à 2 décimales
    let rounded = Math.round(num * 100) / 100
    
    // Supprime les décimales inutiles
    if (rounded === Math.floor(rounded)) {
      return rounded.toString()
    }
    
    // Formate avec virgule française
    return rounded.toString().replace(".", ",")
  }
}
