import { Controller } from "@hotwired/stimulus"
import { unitsTable, unitsFor, factorTo } from "units"

// Quantité d'un ingrédient dans le formulaire de recette.
//
// Ce qui se saisit (un nombre et une unité, « 3 càs ») et ce qui se soumet
// (quantity_base, dans l'unité de base de l'ingrédient, « 9 càc ») sont deux
// choses différentes : ce contrôleur fait le pont, et le champ soumis est
// toujours dérivé de ce qui est affiché.
//
// Le sélecteur d'unité ne convertit pas le nombre affiché, il le réinterprète :
// « 3 » relu en càs vaut 9 càc en base. C'est le geste dont on a besoin quand
// l'IA s'est trompée d'unité en lisant une recette — le nombre était bon,
// l'unité non — et il évite d'avoir à diviser une quantité de tête.
//
// Les unités proposées suivent l'ingrédient sélectionné : celles de son groupe,
// puis celles qu'une équivalence universelle y ramène — une huile se mesure en
// millilitres comme en cuillères. L'unité de base est retenue par défaut. Un
// ingrédient qui n'offre qu'une unité (les pièces) rend le sélecteur inerte
// plutôt que d'ouvrir un choix vide.
export default class extends Controller {
  static targets = ["select", "quantity", "unit", "base"]
  static values = {
    // Posées par ai-panel sur la ligne qu'il clone : la quantité détectée dans
    // la recette et l'unité dans laquelle elle y était écrite. Absentes partout
    // ailleurs — la ligne s'ouvre alors sur l'unité de base de l'ingrédient.
    quantity: Number,
    unit: String
  }

  connect() {
    this.units = unitsTable(this.element)
    this.applyIngredient({ preferredUnit: this.unitValue, quantity: this.quantityValue })
  }

  // Changement d'ingrédient : le groupe d'unités change avec lui, donc les
  // unités proposées. On revient à l'unité de base — l'unité précédente n'a
  // aucune raison d'appartenir au nouveau groupe.
  updateUnit() {
    this.applyIngredient({})
  }

  // Recalcule la quantité soumise depuis ce qui est affiché. Une saisie vide ou
  // une unité inconnue vide le champ : le modèle refusera la préparation plutôt
  // que d'enregistrer une quantité fausse.
  recompute() {
    const factor = factorTo(this.units, this.unitTarget.value, this.unitGroup)
    const quantity = parseFloat(this.quantityTarget.value)

    this.baseTarget.value = factor && Number.isFinite(quantity)
      ? Math.round(quantity * factor * 1000) / 1000
      : ""
  }

  // Aligne le sélecteur d'unités sur l'ingrédient choisi, puis remet la
  // quantité soumise en accord avec l'affichage.
  applyIngredient({ preferredUnit, quantity }) {
    const units = unitsFor(this.units, this.unitGroup)

    this.renderUnits(units, this.selectedUnit(units, preferredUnit, this.baseUnit))
    if (quantity > 0) this.quantityTarget.value = quantity
    this.recompute()
  }

  // Groupe d'unités et unité de base de l'ingrédient sélectionné, portés par son
  // option (le serveur les y pose, ai-panel et ingredient-created aussi).
  get unitGroup() {
    return this.selectTarget.selectedOptions[0]?.dataset.unitGroup || ""
  }

  get baseUnit() {
    return this.selectTarget.selectedOptions[0]?.dataset.unit || ""
  }

  // L'unité souhaitée si l'ingrédient la partage — c'est ainsi que « 3 càs »
  // arrive tel quel du panneau IA —, son unité de base sinon.
  selectedUnit(units, preferredUnit, baseUnit) {
    const offered = units.some(([unit]) => unit === preferredUnit)

    return offered ? preferredUnit : baseUnit
  }

  // Aucun ingrédient sélectionné : un tiret, comme le rendu serveur, plutôt
  // qu'un sélecteur vide.
  renderUnits(units, selected) {
    const entries = units.length > 0 ? units : [ [ "", "—" ] ]

    this.unitTarget.replaceChildren(...entries.map(([ unit, label ]) => {
      const option = document.createElement("option")
      option.value = unit
      option.textContent = label
      option.selected = unit === selected
      return option
    }))

    this.unitTarget.disabled = units.length <= 1
  }
}
