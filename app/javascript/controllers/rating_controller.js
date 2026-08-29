import { Controller } from "@hotwired/stimulus"

/**
 * Controller pour la sélection des étoiles de notation
 * Met à jour visuellement les étoiles lors de la sélection
 * 
 * Usage :
 * <div data-controller="rating">
 *   <label>
 *     <input type="radio" name="rating" value="1" data-action="change->rating#update">
 *     <span data-rating-target="star">☆</span>
 *   </label>
 *   ...
 * </div>
 */
export default class extends Controller {
  static targets = ["star"]

  /**
   * Reflète la note déjà cochée (formulaire réaffiché après une erreur)
   */
  connect() {
    const checked = this.element.querySelector("input[type=radio]:checked")
    this.render(checked ? parseInt(checked.value) : 0)
  }

  /**
   * Met à jour l'affichage des étoiles lors de la sélection
   */
  update(event) {
    this.render(parseInt(event.target.value))
  }

  /**
   * Remplit les `value` premières étoiles, vide les suivantes
   */
  render(selectedValue) {
    this.starTargets.forEach((star, index) => {
      // index est 0-based, selectedValue est 1-based
      if (index < selectedValue) {
        star.textContent = "★"
        star.classList.add("star-filled")
      } else {
        star.textContent = "☆"
        star.classList.remove("star-filled")
      }
    })
  }
}
