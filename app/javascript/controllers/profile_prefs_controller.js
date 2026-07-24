import { Controller } from "@hotwired/stimulus"

/**
 * Sliders interactifs des réglages du foyer (profil/préférences) :
 * - Slider "personnes" avec piste colorée et libellé singulier/pluriel
 * - Slider "repas" avec piste colorée
 */
export default class extends Controller {
  static targets = [
    "peopleSlider", "peopleDisplay", "peopleUnit",
    "mealsSlider", "mealsDisplay"
  ]

  connect() {
    if (this.hasPeopleSliderTarget) this.updateSliderTrack(this.peopleSliderTarget)
    if (this.hasMealsSliderTarget)  this.updateSliderTrack(this.mealsSliderTarget)
  }

  updatePeople() {
    const val = parseInt(this.peopleSliderTarget.value)
    this.peopleDisplayTarget.textContent = val
    this.peopleUnitTarget.textContent = val === 1 ? "personne" : "personnes"
    this.updateSliderTrack(this.peopleSliderTarget)
  }

  updateMeals() {
    const val = parseInt(this.mealsSliderTarget.value)
    this.mealsDisplayTarget.textContent = val
    this.updateSliderTrack(this.mealsSliderTarget)
  }

  // Colorie la portion gauche de la piste en anthracite
  updateSliderTrack(slider) {
    const min = parseInt(slider.min) || 1
    const max = parseInt(slider.max) || 14
    const val = parseInt(slider.value) || 1
    const pct = Math.round(((val - min) / (max - min)) * 100)
    slider.style.background =
      `linear-gradient(to right, var(--color-primary) ${pct}%, var(--color-bg-tertiary) ${pct}%)`
  }
}
