// Comment une quantité s'écrit : « 1,5 kg », « 3 pincées », « 0,5 pièce (200 g) ».
//
// Miroir JS de Quantities::HumanizeService et de PieceUnit. La fiche recette
// recalcule ses quantités dans le navigateur dès qu'on change le nombre de
// convives (cf. le contrôleur servings), et doit écrire exactement ce que le
// serveur avait écrit au chargement : une règle ajoutée d'un côté se recopie de
// l'autre, sans quoi la même ligne change de forme au premier clic.
//
// Ce module n'écrit que des recettes : les pièces y sont dites telles que la
// recette les consomme (miroir de PieceUnit avec round_up: false), et non
// arrondies au supérieur comme sur une liste de courses — un demi-concombre
// reste un demi-concombre. La liste de courses, elle, se rend côté serveur.

import { pieceMeasure } from 'units'

const COUNT = 'count'

// Seuils et équivalences — mêmes valeurs que les constantes de
// Quantities::HumanizeService et de PieceUnit.
const MASS_THRESHOLD = 1000    // g → kg
const VOLUME_THRESHOLD = 1000  // ml → L
const CAC_PER_CAS = 3          // 3 càc = 1 càs
const CAC_PER_PINCEE = 0.25    // 1 pincée = 0,25 càc
const COUNT_DECIMALS = 1       // une fraction de pièce se lit au dixième
const PRECISION = 3            // les quantités de base vivent au millième

// La quantité d'un ingrédient telle que la fiche recette la montre : d'abord en
// pièces quand le catalogue leur donne un nom, sinon dans son unité.
// Miroir de Preparation#display_quantity.
//
// @param quantity quantité en unité de base de l'ingrédient, mise à l'échelle
// @param ingredient { unitGroup, pieceLabel, piecePlural, pieceWeight, pieceVolume }
// @return {string}
export function quantitySentence(quantity, ingredient) {
  // Le serveur ne voit jamais que des quantités au millième
  // (Preparation#scaled_quantity) : on s'y ramène pour qu'un facteur comme 1/3
  // n'écrive pas 0,30000000000000004 là où Ruby écrit 0,3.
  const scaled = roundTo(quantity, PRECISION)

  return pieceSentence(scaled, ingredient) ?? humanize(scaled, ingredient.unitGroup)
}

// === Les pièces (miroir de PieceUnit) ===

// La phrase d'un ingrédient qui se compte, null quand il n'y a rien à compter.
// Miroir de PieceUnit#sentence_for.
function pieceSentence(quantity, ingredient) {
  const parts = describePieces(quantity, ingredient)
  if (!parts) return null

  const pieces = `${parts.count} ${parts.label}`
  if (!parts.measure) return pieces

  // Le « pour » n'annonce qu'un surplus d'achat : « 4 blancs pour 500 g », là où
  // les pièces déduites d'un poids ont été arrondies au-dessus. Les parenthèses
  // disent l'équivalence.
  return parts.exact ? `${pieces} (${parts.measure})` : `${pieces} pour ${parts.measure}`
}

// Ce qu'il y a à écrire : le compte, le nom accordé, la mesure, et si les deux
// s'équivalent. null quand il n'y a rien à compter — pas de nom de pièce, ou
// moins d'un dixième de pièce, que l'appelant dira mieux en la mesurant.
// Miroir de PieceUnit#describe.
function describePieces(quantity, ingredient) {
  if (!ingredient.pieceLabel) return null

  const exactCount = exactCountFor(quantity, ingredient)
  if (exactCount === null) return null

  // Ce qui se compte se dit tel quel — un demi-concombre se coupe. Ce qui se
  // pèse n'a que des pièces déduites, arrondies au supérieur : « 3,33 blancs »
  // n'existe dans aucun frigo.
  const counted = ingredient.unitGroup === COUNT
  const count = counted ? roundTo(exactCount, COUNT_DECIMALS)
                        : Math.ceil(roundTo(exactCount, PRECISION))
  if (!count) return null

  const measure = measureFor(quantity, ingredient)

  return {
    count:   formatNumber(count),
    label:   labelFor(count, ingredient),
    measure: measure && humanize(measure.quantity, measure.unitGroup),
    exact:   counted || isIntegerLike(roundTo(exactCount, PRECISION))
  }
}

// Le nombre de pièces AVANT arrondi, null quand rien ne permet de compter.
// Miroir de PieceUnit#exact_count_for.
function exactCountFor(quantity, ingredient) {
  if (ingredient.unitGroup === COUNT) return quantity

  const measure = pieceMeasure(ingredient)

  return measure ? quantity / measure[0] : null
}

// La mesure correspondant à cette quantité — ce que la recette consomme :
// la quantité elle-même pour ce qui se pèse, ce que pèsent les pièces pour ce
// qui se compte. Miroir de PieceUnit#measure_for.
function measureFor(quantity, ingredient) {
  const measure = pieceMeasure(ingredient)
  if (!measure) return null

  const [ size, measureGroup ] = measure
  if (ingredient.unitGroup !== COUNT) return { quantity, unitGroup: ingredient.unitGroup }

  return { quantity: quantity * size, unitGroup: measureGroup }
}

// Le nom de la pièce, accordé. Miroir de PieceUnit#label_for : le pluriel n'est
// écrit en base que là où le français refuse le « s », et ne commence qu'à deux.
function labelFor(count, { pieceLabel, piecePlural }) {
  if (Math.abs(count) < 2) return pieceLabel

  return piecePlural || `${pieceLabel}s`
}

// === L'unité (miroir de Quantities::HumanizeService) ===

// La quantité écrite dans son unité, convertie là où l'unité devient illisible :
// « 1,5 kg », « 2 L », « 3 pincées ».
function humanize(quantity, unitGroup) {
  const { value, unit } = humanizeIn(quantity, unitGroup)
  const display = formatNumber(value)

  return unit ? `${display} ${unit}` : display
}

function humanizeIn(quantity, unitGroup) {
  switch (unitGroup) {
    case 'mass':   return withThreshold(quantity, MASS_THRESHOLD, 'g', 'kg')
    case 'volume': return withThreshold(quantity, VOLUME_THRESHOLD, 'ml', 'L')
    case 'spoon':  return humanizeSpoon(quantity)
    case COUNT:    return humanizeCount(quantity)
    default:       return { value: quantity, unit: '' }
  }
}

// g → kg, ml → L : au-delà du millier, c'est la grande unité qui se lit.
function withThreshold(quantity, threshold, smallUnit, largeUnit) {
  if (quantity >= threshold) return { value: quantity / 1000, unit: largeUnit }

  return { value: quantity, unit: smallUnit }
}

// Les cuillères : 3 càc font 1 càs, et sous la cuillère à café on compte en
// pincées — personne ne dose 0,75 càc de paprika.
function humanizeSpoon(quantity) {
  if (quantity > 0 && quantity < 1) return humanizePincees(quantity)

  const spoons = Math.floor(quantity / CAC_PER_CAS)
  const remainder = quantity % CAC_PER_CAS

  if (remainder === 0) return { value: spoons, unit: 'càs' }
  if (spoons === 0) return { value: remainder, unit: 'càc' }

  // Au-delà d'une cuillère à soupe, les fractions restent plus lisibles en càs.
  return { value: quantity / CAC_PER_CAS, unit: 'càs' }
}

function humanizePincees(quantity) {
  // Une quantité positive fait au moins une pincée, si petite soit-elle.
  const pincees = Math.round(quantity / CAC_PER_PINCEE) || 1

  return { value: pincees, unit: pincees > 1 ? 'pincées' : 'pincée' }
}

// Un compte sans nom de pièce se lit comme une fraction de pièce, au dixième.
// Le « entier dès deux » de HumanizeService est une règle d'achat : elle ne
// s'applique qu'à la liste de courses, qui se rend côté serveur.
function humanizeCount(quantity) {
  return { value: roundedNumber(quantity, COUNT_DECIMALS), unit: '' }
}

// === Écriture des nombres ===

// L'arrondi voulu, mais jamais au point de faire disparaître une quantité
// minuscule : on descend chercher son premier chiffre significatif.
// Miroir de HumanizeService#rounded_number.
function roundedNumber(value, maxDecimals = 2) {
  let decimals = maxDecimals
  while (value > 0 && roundTo(value, decimals) === 0 && decimals < 6) decimals += 1

  return roundTo(value, decimals)
}

// Virgule française. Les zéros inutiles, que Ruby doit retirer à la main,
// n'existent pas dans un nombre JS converti en texte.
function formatNumber(value) {
  return String(roundedNumber(value)).replace('.', ',')
}

const roundTo = (value, decimals) => {
  const factor = 10 ** decimals

  return Math.round(value * factor) / factor
}

const isIntegerLike = (value) => Number.isInteger(value)
