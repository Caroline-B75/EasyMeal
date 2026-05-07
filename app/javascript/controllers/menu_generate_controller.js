import { Controller } from "@hotwired/stimulus"

/**
 * Gère l'interactivité du formulaire de génération de menu :
 * - Sélection de régime alimentaire (radio cards visuels avec ARIA)
 * - Sliders pour le nombre de personnes et le nombre de repas
 * - État de chargement au submit
 */
export default class extends Controller {
  static targets = [
    "dietOption", "dietInput",
    "peopleSlider", "peopleDisplay", "peopleUnit",
    "mealsSlider", "mealsDisplay",
    "submitBtn"
  ]

  connect() {
    this.updateAllSliderTracks()
  }

  // ── Régime alimentaire ──────────────────────────────────

  selectDiet(event) {
    const option = event.currentTarget

    // Mise à jour des classes et ARIA
    this.dietOptionTargets.forEach(opt => {
      opt.classList.remove("selected")
      opt.setAttribute("aria-checked", "false")
    })
    option.classList.add("selected")
    option.setAttribute("aria-checked", "true")

    // Cocher le radio button correspondant
    const radio = option.querySelector("input[type='radio']")
    if (radio) radio.checked = true
  }

  // ── Nombre de personnes (slider) ────────────────────────

  updatePeople() {
    const val = parseInt(this.peopleSliderTarget.value)
    this.peopleDisplayTarget.textContent = val
    this.peopleUnitTarget.textContent = val === 1 ? "personne" : "personnes"
    this.updateSliderTrack(this.peopleSliderTarget)
  }

  // ── Nombre de repas (slider) ────────────────────────────

  updateMeals() {
    const val = parseInt(this.mealsSliderTarget.value)
    this.mealsDisplayTarget.textContent = val
    this.updateSliderTrack(this.mealsSliderTarget)
  }

  // ── Slider track visual update ──────────────────────────

  updateAllSliderTracks() {
    if (this.hasPeopleSliderTarget) {
      this.updateSliderTrack(this.peopleSliderTarget)
    }
    if (this.hasMealsSliderTarget) {
      this.updateSliderTrack(this.mealsSliderTarget)
    }
  }

  updateSliderTrack(slider) {
    const min = parseInt(slider.min) || 1
    const max = parseInt(slider.max) || 14
    const val = parseInt(slider.value) || 7
    const pct = Math.round(((val - min) / (max - min)) * 100)
    slider.style.background = `linear-gradient(to right, var(--color-primary) ${pct}%, var(--color-bg-tertiary) ${pct}%)`
  }

  // ── Submit avec état de chargement ──────────────────────

  submitBtnTargetConnected(btn) {
    btn.closest("form")?.addEventListener("submit", () => {
      this.showLoading(btn)
    })
  }

  showLoading(btn) {
    btn.disabled = true
    const svgSpinner = `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"
      class="mn-spinning" style="width:16px;height:16px">
      <path d="M12 2v4M12 18v4M4.93 4.93l2.83 2.83M16.24 16.24l2.83 2.83M2 12h4M18 12h4M4.93 19.07l2.83-2.83M16.24 7.76l2.83-2.83"/>
    </svg>`
    btn.innerHTML = `${svgSpinner} Génération en cours…`
  }
}
