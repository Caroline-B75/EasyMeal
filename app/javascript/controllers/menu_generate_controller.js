import { Controller } from "@hotwired/stimulus"

/**
 * Gère l'interactivité du formulaire de génération de menu :
 * - Sélection de régime alimentaire (radio cards visuels)
 * - Compteur +/- pour le nombre de personnes
 * - Slider pour le nombre de repas
 * - Résumé dynamique en temps réel
 * - État de chargement au submit
 */
export default class extends Controller {
  static targets = [
    "dietOption", "dietInput",
    "peopleDisplay", "peopleInput", "peopleUnit",
    "mealsSlider", "mealsDisplay",
    "nameInput",
    "sumDiet", "sumPeople", "sumMeals", "sumName",
    "submitBtn"
  ]

  static values = {
    defaultName: String
  }

  // Labels des régimes pour le résumé
  static dietLabels = {
    omnivore: "Omnivore",
    vegetarien: "Végétarien",
    vegan: "Vegan",
    pescetarien: "Pescétarien"
  }

  connect() {
    this.updateSliderTrack()
  }

  // ── Régime alimentaire ──────────────────────────────────

  selectDiet(event) {
    const option = event.currentTarget
    this.dietOptionTargets.forEach(opt => opt.classList.remove("selected"))
    option.classList.add("selected")

    // Cocher le radio button correspondant
    const radio = option.querySelector("input[type='radio']")
    if (radio) radio.checked = true

    this.updateSummary()
  }

  // ── Nombre de personnes ─────────────────────────────────

  get people() {
    return parseInt(this.peopleInputTarget.value) || 1
  }

  set people(val) {
    const clamped = Math.max(1, Math.min(12, val))
    this.peopleInputTarget.value = clamped
    this.peopleDisplayTarget.textContent = clamped
    this.peopleUnitTarget.textContent = clamped === 1 ? "personne par repas" : "personnes par repas"
    this.sumPeopleTarget.textContent = `${clamped} ${clamped === 1 ? "personne" : "personnes"}`
  }

  incrementPeople() {
    this.people = this.people + 1
  }

  decrementPeople() {
    this.people = this.people - 1
  }

  // ── Nombre de repas ─────────────────────────────────────

  updateMeals() {
    const val = parseInt(this.mealsSliderTarget.value)
    this.mealsDisplayTarget.textContent = val
    this.sumMealsTarget.textContent = `${val} repas`
    this.updateSliderTrack()
  }

  updateSliderTrack() {
    const slider = this.mealsSliderTarget
    const min = parseInt(slider.min) || 1
    const max = parseInt(slider.max) || 14
    const val = parseInt(slider.value) || 7
    const pct = Math.round(((val - min) / (max - min)) * 100)
    slider.style.background = `linear-gradient(to right, var(--color-primary) ${pct}%, var(--color-bg-tertiary) ${pct}%)`
  }

  // ── Nom du menu ─────────────────────────────────────────

  updateName() {
    const val = this.nameInputTarget.value.trim()
    this.sumNameTarget.textContent = val || this.defaultNameValue
  }

  // ── Résumé global ───────────────────────────────────────

  updateSummary() {
    // Mise à jour du régime dans le résumé
    const checkedRadio = this.dietInputTargets.find(r => r.checked)
    if (checkedRadio) {
      const dietKey = checkedRadio.value
      this.sumDietTarget.textContent = this.constructor.dietLabels[dietKey] || dietKey
    }
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
