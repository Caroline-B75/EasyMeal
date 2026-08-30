// Lecture de la table des unités du projet — groupes, facteurs, libellés,
// équivalences — telle que Ruby la sérialise (Units.table) sur le formulaire de
// recette. Les deux contrôleurs qui manipulent des unités (panneau IA, quantité
// d'une préparation) passent par ici : aucun facteur de conversion n'est recopié
// en JS.

// Unité d'une quantité qui n'en porte pas : « 3 oeufs » se compte en pièces.
// Miroir de Units::DEFAULT_UNIT.
const DEFAULT_UNIT = 'piece'

const EMPTY_TABLE = { units: {}, equivalences: {} }

// La table, lue sur l'ancêtre qui la porte. Une page qui ne la porterait pas
// rend une table vide : les conversions échouent alors franchement plutôt que
// de convertir avec des facteurs devinés.
export function unitsTable(element) {
  const holder = element.closest('[data-units-table]')
  if (!holder) return EMPTY_TABLE

  try {
    return JSON.parse(holder.dataset.unitsTable)
  } catch {
    return EMPTY_TABLE
  }
}

// Groupe d'unités et facteur d'une unité écrite, undefined si elle est
// illisible. Miroir de Units.definition, règle du silence comprise.
function unitDefinition(table, unit) {
  const key = (unit || '').trim()

  return table.units[key === '' ? DEFAULT_UNIT : key]
}

// Facteur menant d'une unité à l'unité de base d'un groupe, null quand rien
// d'universel ne les relie. Miroir de Units.factor_to.
function factorTo(table, unit, unitGroup) {
  const definition = unitDefinition(table, unit)
  if (!definition) return null
  if (definition.unit_group === unitGroup) return definition.factor

  const equivalence = equivalenceFor(table, definition.unit_group, unitGroup)

  return equivalence ? definition.factor * equivalence.factor : null
}

function equivalenceFor(table, fromGroup, toGroup) {
  return table.equivalences[fromGroup + '>' + toGroup]
}

// Libellé d'une unité ; une unité inconnue s'écrit telle qu'elle est arrivée.
export function unitLabel(table, unit) {
  return table.units[unit]?.label || unit || ''
}

// Unités qu'on propose à la saisie pour un ingrédient de ce groupe :
// [[unité, libellé]]. Miroir de Units.select_options, même ordre — celles du
// groupe d'abord, puis celles qu'une équivalence y ramène et qu'on accepte de
// proposer (une épice se dose en cuillères, pas en centilitres).
function unitsFor(table, unitGroup) {
  const units = Object.keys(table.units)
  const own = units.filter((unit) => table.units[unit].unit_group === unitGroup)
  const bridged = units.filter((unit) => {
    const group = table.units[unit].unit_group
    return group !== unitGroup && equivalenceFor(table, group, unitGroup)?.offered
  })

  return [ ...own, ...bridged ].map((unit) => [ unit, table.units[unit].label ])
}

// L'unité est-elle proposée à la saisie pour ce groupe ? Le panneau IA s'en sert
// pour ne poser dans le formulaire que des unités que son sélecteur contient.
export function unitOffered(table, unit, unitGroup) {
  return unitsFor(table, unitGroup).some(([ offered ]) => offered === unit)
}

// === Ce qui dépend de l'ingrédient ===
//
// Tout ce qui précède est universel : une cuillère à soupe fait 15 ml quoi
// qu'on y mette. Ce qui suit ne l'est pas — deux aubergines ne font 600 g que
// parce que CET ingrédient pèse 300 g la pièce. C'est la frontière que trace
// Units côté Ruby, et les fonctions ci-dessous sont le miroir exact de ce qui
// vit de l'autre côté : UnitConversionService et PieceCounting.
//
// L'ingrédient y est réduit à ce qui sert : { unitGroup, pieceWeight,
// pieceVolume, pieceLabel, density, densitySource }.

const MASS = 'mass'
const VOLUME = 'volume'
const COUNT = 'count'

// Même arrondi que côté Ruby : les quantités de base vivent au millième.
const round3 = (value) => Math.round(value * 1000) / 1000

// Ce que contient UNE pièce, et dans quelle langue : [300, 'mass'] pour une
// aubergine, [1000, 'volume'] pour une brique. null quand rien ne le dit.
// Miroir de PieceCounting#piece_measure — les deux ne cohabitent jamais.
function pieceMeasure({ pieceWeight, pieceVolume }) {
  const weight = parseFloat(pieceWeight)
  if (weight > 0) return [ weight, MASS ]

  const volume = parseFloat(pieceVolume)
  if (volume > 0) return [ volume, VOLUME ]

  return null
}

// Convertit une quantité depuis fromUnit vers l'unité de base de l'ingrédient.
// null si rien ne les relie : unités incompatibles, unité illisible
// (« 2 tranches »), ou coefficient absent du catalogue.
//
// Miroir de UnitConversionService.convert, dans le même ordre : le facteur
// connu d'avance, puis les deux ponts que porte l'ingrédient.
export function convert(table, quantity, fromUnit, ingredient) {
  const factor = factorTo(table, fromUnit, ingredient.unitGroup)
  if (factor) return round3(quantity * factor)
  if (!unitDefinition(table, fromUnit)) return null

  return bridgeByPieceSize(table, quantity, fromUnit, ingredient) ??
         bridgeByDensity(table, quantity, fromUnit, ingredient)
}

// Pont pièce ↔ mesure : « 2 tranches » de jambon deviennent 80 g si le
// catalogue sait qu'une tranche pèse 40 g, « 1 brique » devient 1 L s'il sait
// ce que contient une brique — et rien du tout s'il l'ignore.
function bridgeByPieceSize(table, qty, fromUnit, ingredient) {
  const measure = pieceMeasure(ingredient)
  if (!measure) return null

  const [ size, measureGroup ] = measure
  if (ingredient.unitGroup === measureGroup) {
    return through(table, qty, fromUnit, COUNT, (pieces) => pieces * size)
  }
  if (ingredient.unitGroup === COUNT) {
    return through(table, qty, fromUnit, measureGroup, (value) => value / size)
  }

  return null
}

// Pont mesure ↔ masse par la densité : « 1 càs » de farine devient 8,25 g si le
// catalogue sait qu'un millilitre en pèse 0,55.
function bridgeByDensity(table, qty, fromUnit, { unitGroup, density }) {
  const value = parseFloat(density)
  if (!(value > 0)) return null

  if (unitGroup === MASS) return through(table, qty, fromUnit, VOLUME, (ml) => ml * value)

  const toBase = factorTo(table, 'ml', unitGroup)
  return toBase ? through(table, qty, fromUnit, MASS, (grams) => grams / value * toBase) : null
}

// Amène la quantité dans l'unité de base d'un groupe intermédiaire, puis laisse
// le coefficient de l'ingrédient finir le trajet (miroir de convert_through).
function through(table, qty, fromUnit, pivotGroup, finish) {
  const factor = factorTo(table, fromUnit, pivotGroup)

  return factor ? round3(finish(qty * factor)) : null
}

// La conversion repose-t-elle sur une densité estimée par l'IA ? Si la retirer
// casse la conversion, c'est elle qui l'a rendue possible — et le résultat n'est
// juste qu'à une estimation près. Miroir de UnitConversionService.estimated?
export function usesEstimatedDensity(table, fromUnit, ingredient) {
  if (ingredient.densitySource !== 'ai') return false
  if (convert(table, 1, fromUnit, ingredient) === null) return false

  return convert(table, 1, fromUnit, { ...ingredient, density: null }) === null
}

// Les unités qu'on propose à la saisie pour CET ingrédient : celles de son
// groupe, plus celles que sa pièce y ramène. Miroir de
// PieceCounting#unit_select_options, dans les deux sens comme lui — ce qui se
// pèse gagne sa pièce, ce qui se compte gagne sa mesure.
export function unitsForIngredient(table, ingredient) {
  const own = unitsFor(table, ingredient.unitGroup).map(([ unit, label ]) => (
    unit === DEFAULT_UNIT && ingredient.pieceLabel ? [ unit, ingredient.pieceLabel ] : [ unit, label ]
  ))

  return [ ...own, ...pieceBridgeOptions(table, ingredient) ]
}

// Ce que la pièce ajoute au sélecteur, et rien de plus.
function pieceBridgeOptions(table, ingredient) {
  if (!ingredient.pieceLabel) return []
  if (ingredient.unitGroup !== COUNT) return [ [ DEFAULT_UNIT, ingredient.pieceLabel ] ]

  const measure = pieceMeasure(ingredient)

  return measure ? unitsFor(table, measure[1]) : []
}
