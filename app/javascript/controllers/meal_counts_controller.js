import { Controller } from "@hotwired/stimulus"

/**
 * Steppers de répartition des repas par moment (UC7, chapitre 2).
 *
 * Un stepper par moment de la journée : les boutons − / + font varier un champ
 * caché borné à [min, max] — le seul que le serveur lise. Le contrôleur gère
 * aussi l'option « même petit-déjeuner toute la semaine », qui n'a de sens qu'à
 * partir de deux petits-déjeuners.
 *
 * Il ne connaît aucun mot de français : les formes courtes accordées voyagent
 * dans les data-attributes des champs, écrites une seule fois dans les locales.
 *
 * Chaque changement est annoncé par l'événement `meal-counts:change`
 * (detail : { total, summary }). Le formulaire de génération s'en sert pour sa
 * barre de résumé et l'état de son bouton ; les préférences du foyer, qui
 * réutilisent le même partial, l'ignorent simplement.
 */
export default class extends Controller {
  static targets = ["input", "display", "decrement", "increment", "sameBreakfast"]

  static values = {
    min: Number,
    max: Number,
    breakfast: String,
    sameBreakfastMin: Number,
    emptySummary: String
  }

  connect() {
    // Le serveur a déjà rendu l'état initial (valeurs, bornes, option) : on ne
    // fait qu'annoncer la répartition de départ à qui l'écoute.
    this._notifyChange()
  }

  increment({ params: { type } }) {
    this._step(type, +1)
  }

  decrement({ params: { type } }) {
    this._step(type, -1)
  }

  // ── Interne ─────────────────────────────────────────────────

  // Applique une variation à un moment, puis remet tout le reste en cohérence.
  _step(type, delta) {
    const input = this._targetFor(this.inputTargets, type)
    if (!input) return

    const value = Math.min(Math.max(Number(input.value) + delta, this.minValue), this.maxValue)
    input.value = value
    this._targetFor(this.displayTargets, type).textContent = value

    // Aux bornes, un bouton désactivé vaut mieux qu'un clic sans effet.
    this._targetFor(this.decrementTargets, type).disabled = value <= this.minValue
    this._targetFor(this.incrementTargets, type).disabled = value >= this.maxValue

    this._refreshSameBreakfast()
    this._notifyChange()
  }

  // L'option de répétition suit le stepper Petit-déj : masquée sous le seuil,
  // et décochée au passage — on ne soumet pas un choix devenu invisible.
  _refreshSameBreakfast() {
    if (!this.hasSameBreakfastTarget) return

    const input = this._targetFor(this.inputTargets, this.breakfastValue)
    const enabled = Number(input?.value || 0) >= this.sameBreakfastMinValue

    this.sameBreakfastTarget.hidden = !enabled
    if (!enabled) this.sameBreakfastTarget.querySelector("input").checked = false
  }

  _notifyChange() {
    this.dispatch("change", { detail: { total: this._total, summary: this._summary } })
  }

  // Cible d'un moment donné, dans n'importe quelle liste de cibles.
  _targetFor(targets, type) {
    return targets.find((element) => element.dataset.mealType === type)
  }

  get _total() {
    return this.inputTargets.reduce((sum, input) => sum + Number(input.value), 0)
  }

  // « 7 petits-déjs · 2 déjs · 1 apéro » — seuls les moments commandés comptent.
  // Réplique exacte de MenusHelper#meal_counts_summary, côté client.
  get _summary() {
    const parts = this.inputTargets.flatMap((input) => {
      const count = Number(input.value)
      if (count < 1) return []

      const { shortLabelOne, shortLabelOther } = input.dataset
      return [`${count} ${count === 1 ? shortLabelOne : shortLabelOther}`]
    })

    return parts.join(" · ") || this.emptySummaryValue
  }
}
