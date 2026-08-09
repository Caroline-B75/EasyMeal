import { Controller } from "@hotwired/stimulus"
import { paintSliderTrack } from "slider_track"

/**
 * Slider interactif des réglages du foyer (profil/préférences) : nombre de
 * personnes, avec piste colorée et libellé accordé.
 *
 * La répartition des repas, elle, est pilotée par le contrôleur meal-counts,
 * partagé avec le formulaire de génération de menu.
 */
export default class extends Controller {
  static targets = ["peopleSlider", "peopleDisplay", "peopleUnit"]

  connect() {
    if (this.hasPeopleSliderTarget) paintSliderTrack(this.peopleSliderTarget)
  }

  updatePeople() {
    const val = parseInt(this.peopleSliderTarget.value)
    this.peopleDisplayTarget.textContent = val
    this.peopleUnitTarget.textContent = val === 1 ? "personne" : "personnes"
    paintSliderTrack(this.peopleSliderTarget)
  }
}
