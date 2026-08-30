import { Controller } from "@hotwired/stimulus"
import { unitsTable, unitsForIngredient, convert } from "units"

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
// celles qu'une équivalence universelle y ramène — une huile se mesure en
// millilitres comme en cuillères —, et celles que sa pièce y ajoute : « 2
// aubergines » se saisit comme 600 g, « 200 g d'oignon » comme 1,8 oignon. Les
// unités et leurs conversions viennent toutes de units.js, miroir du Ruby :
// aucune règle n'est réécrite ici.
//
// L'unité de base est retenue par défaut. Un ingrédient qui n'offre qu'une
// unité rend le sélecteur inerte plutôt que d'ouvrir un choix vide.
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
    const quantity = parseFloat(this.quantityTarget.value)
    const converted = Number.isFinite(quantity)
      ? convert(this.units, quantity, this.unitTarget.value, this.ingredient)
      : null

    this.baseTarget.value = converted ?? ""
  }

  // Aligne le sélecteur d'unités sur l'ingrédient choisi, puis remet la
  // quantité soumise en accord avec l'affichage.
  applyIngredient({ preferredUnit, quantity }) {
    const units = unitsForIngredient(this.units, this.ingredient)

    this.renderUnits(units, this.selectedUnit(units, preferredUnit, this.baseUnit))
    if (quantity > 0) this.quantityTarget.value = quantity
    this.recompute()
  }

  // L'ingrédient sélectionné, réduit à ce qui décide des unités et de leur
  // conversion. Tout est porté par son option — le serveur l'y pose
  // (ingredient_option_data), preparation_rows aussi pour celles qu'il crée.
  //
  // Pas de densité ici, et ce n'est pas un oubli : le sélecteur ne propose que
  // des unités qu'une équivalence universelle ou la pièce savent convertir. La
  // cuillère n'est offerte qu'aux liquides, où elle se convertit sans peser.
  get ingredient() {
    const { unit, unitGroup, pieceLabel, pieceWeight, pieceVolume } =
      this.selectTarget.selectedOptions[0]?.dataset || {}

    return { unitGroup: unitGroup || "", pieceLabel, pieceWeight, pieceVolume }
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
