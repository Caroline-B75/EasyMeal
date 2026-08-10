import { Controller } from "@hotwired/stimulus"

/**
 * Boutons − / + autour d'un champ numérique.
 *
 * Le champ reste la seule source de vérité : c'est lui qui est soumis, lui qui
 * porte ses bornes (attributs min / max) et il reste saisissable au clavier —
 * les boutons ne sont qu'un raccourci. Sans JavaScript, le formulaire fonctionne
 * donc à l'identique, boutons inertes en moins.
 *
 * Usage :
 *   <div data-controller="number-stepper">
 *     <button type="button" data-action="number-stepper#decrement"
 *             data-number-stepper-target="decrement">−</button>
 *     <input type="number" min="1" data-number-stepper-target="input"
 *            data-action="input->number-stepper#refresh">
 *     <button type="button" data-action="number-stepper#increment"
 *             data-number-stepper-target="increment">+</button>
 *   </div>
 */
export default class extends Controller {
  static targets = ["input", "decrement", "increment"]

  connect() {
    this.refresh()
  }

  increment() {
    this._step(+1)
  }

  decrement() {
    this._step(-1)
  }

  // Aux bornes, un bouton désactivé vaut mieux qu'un clic sans effet. Rejoué
  // après une saisie au clavier, qui peut atteindre une borne elle aussi.
  refresh() {
    const value = this._value

    if (this.hasDecrementTarget) this.decrementTarget.disabled = value <= this._min
    if (this.hasIncrementTarget) this.incrementTarget.disabled = value >= this._max
  }

  // ── Interne ─────────────────────────────────────────────────

  _step(delta) {
    const value = this._value + delta
    this.inputTarget.value = Math.min(Math.max(value, this._min), this._max)

    // Une valeur posée par programme n'émet aucun événement : sans cette
    // annonce, tout ce qui écoute le champ (validation, auto-submit) l'ignore.
    this.inputTarget.dispatchEvent(new Event("input", { bubbles: true }))
    this.refresh()
  }

  // Un champ vide vaut 0 : depuis le vide, les deux boutons ramènent donc à la
  // borne la plus proche plutôt que de produire une valeur hors bornes.
  get _value() {
    return Number(this.inputTarget.value) || 0
  }

  get _min() {
    return this._bound("min", -Infinity)
  }

  get _max() {
    return this._bound("max", Infinity)
  }

  // Borne lue sur le champ ; absente ou non numérique, elle ne borne rien.
  _bound(name, fallback) {
    const raw = this.inputTarget.getAttribute(name)

    return raw !== null && Number.isFinite(Number(raw)) ? Number(raw) : fallback
  }
}
