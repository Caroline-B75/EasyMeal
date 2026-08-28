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
export function unitDefinition(table, unit) {
  const key = (unit || '').trim()

  return table.units[key === '' ? DEFAULT_UNIT : key]
}

// Facteur menant d'une unité à l'unité de base d'un groupe, null quand rien
// d'universel ne les relie. Miroir de Units.factor_to.
export function factorTo(table, unit, unitGroup) {
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
export function unitsFor(table, unitGroup) {
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
