import { Controller } from "@hotwired/stimulus"
import { paintSliderTrack } from "slider_track"

/**
 * Interactivité du formulaire de paramètres de menu (génération / régénération) :
 * - Sélection du régime alimentaire (cartes radio accessibles ARIA)
 * - Slider "personnes" avec piste colorée
 * - Répartition des repas : écoute les steppers du contrôleur meal-counts
 * - Barre résumé synchronisée en temps réel
 * - État de chargement au submit
 *
 * Les accès aux cibles de résumé sont gardés par `has…Target` pour rester
 * robuste si la barre résumé venait à être retirée d'un parcours.
 */
export default class extends Controller {
  static targets = [
    "dietOption", "dietInput",
    "peopleSlider", "peopleDisplay", "peopleUnit",
    "nameInput",
    "sumDiet", "sumPeople", "sumMeals", "sumName",
    "emptyMealsHint", "submitBtn"
  ]

  static values = { defaultName: String }

  connect() {
    if (this.hasPeopleSliderTarget) paintSliderTrack(this.peopleSliderTarget)
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

    // Résumé : libellé lisible lu depuis la carte sélectionnée
    if (this.hasSumDietTarget) {
      const name = option.querySelector(".mn-diet-name")
      if (name) this.sumDietTarget.textContent = name.textContent
    }
  }

  // ── Nombre de personnes (slider) ────────────────────────

  updatePeople() {
    const val = parseInt(this.peopleSliderTarget.value)
    const unit = val === 1 ? "personne" : "personnes"
    this.peopleDisplayTarget.textContent = val
    this.peopleUnitTarget.textContent = unit
    paintSliderTrack(this.peopleSliderTarget)
    if (this.hasSumPeopleTarget) this.sumPeopleTarget.textContent = `${val} ${unit}`
  }

  // ── Répartition des repas (steppers meal-counts) ────────

  // Réagit à l'événement meal-counts:change émis par les steppers : le résumé
  // reprend la répartition, et une semaine sans aucun repas ne se génère pas —
  // le bouton se désactive plutôt que de laisser partir une commande vide.
  updateMealCounts({ detail: { total, summary } }) {
    if (this.hasSumMealsTarget) this.sumMealsTarget.textContent = summary
    if (this.hasEmptyMealsHintTarget) this.emptyMealsHintTarget.hidden = total > 0
    if (this.hasSubmitBtnTarget) this.submitBtnTarget.disabled = total === 0
  }

  // ── Nom du menu ─────────────────────────────────────────

  updateName() {
    if (!this.hasSumNameTarget) return
    this.sumNameTarget.textContent = this.nameInputTarget.value.trim() || this.defaultNameValue
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
