import { TEMPLATE_SELECTOR, CONTAINER_SELECTOR, FIELDS_SELECTOR, DESTROY_SELECTOR,
         buildFields, removeFields } from "nested_fields"

// Les lignes d'ingrédient du formulaire de recette : le catalogue qu'elles se
// partagent, et comment en poser une nouvelle.
//
// Le catalogue approche les 600 entrées : le répéter dans chaque ligne pesait
// 58 Ko par ligne. Il n'est donc rendu qu'une fois, dans le modèle de ligne du
// nested-form — un <template>, dont le contenu vit dans un DocumentFragment
// invisible aux sélecteurs posés sur `document`. Ce module est le seul endroit
// qui sache y descendre : sans lui, un ingrédient créé à la volée n'entrait que
// dans les lignes déjà à l'écran, et la ligne suivante — clonée du modèle —
// repartait sans lui.

const INGREDIENT_SELECT = 'select[name*="ingredient_id"]'
// Les ingrédients d'un sélecteur, hors invite « Choisir un ingrédient... »
const INGREDIENT_OPTIONS = "option[value]:not([value=''])"

const rowTemplate = () => document.querySelector(TEMPLATE_SELECTOR)

// Le sélecteur d'ingrédient du modèle de ligne : la seule liste complète de la page.
export function catalogSelect() {
  return rowTemplate()?.content.querySelector(INGREDIENT_SELECT) || null
}

export function catalogOptions() {
  return Array.from(catalogSelect()?.querySelectorAll(INGREDIENT_OPTIONS) || [])
}

// Le sélecteur d'ingrédient d'une ligne.
export function ingredientSelect(fields) {
  return fields.querySelector(INGREDIENT_SELECT)
}

// Les lignes d'ingrédient posées dans le formulaire, dans leur ordre d'affichage.
export function preparationRows() {
  return Array.from(document.querySelectorAll(`${CONTAINER_SELECTOR} > ${FIELDS_SELECTOR}`))
}

// La ligne qui porte déjà cet ingrédient, s'il y en a une. Une recette n'en
// tient qu'une par ingrédient — un index d'unicité le garantit en base —, et
// c'est ici qu'on le vérifie avant d'en poser une seconde. Une ligne marquée
// pour suppression ne compte pas : elle ne sera plus là après la sauvegarde.
export function preparationFor(ingredientId) {
  return preparationRows().find((row) => (
    ingredientSelect(row)?.value === String(ingredientId) &&
    row.querySelector(DESTROY_SELECTOR)?.value !== "1"
  )) || null
}

// Vide la liste d'ingrédients du formulaire, ligne à ligne et selon la même
// règle que la croix de chaque ligne : ce qui n'a jamais été enregistré quitte
// le DOM, ce qui l'a été part marqué pour suppression.
export function clearPreparationRows() {
  preparationRows().forEach(removeFields)
}

// Inscrit un ingrédient tout juste créé dans le catalogue et dans les lignes déjà
// à l'écran, à sa place alphabétique. Le catalogue d'abord : c'est de lui que
// seront clonées les lignes suivantes.
export function registerIngredient(ingredient) {
  const catalog = catalogSelect()
  const selects = [ ...(catalog ? [ catalog ] : []), ...document.querySelectorAll(INGREDIENT_SELECT) ]

  selects.forEach((select) => insertOption(select, ingredient))
}

function insertOption(select, { id, label, baseUnit, unitGroup, pieceLabel, pieceWeight, pieceVolume }) {
  if (select.querySelector(`option[value="${CSS.escape(String(id))}"]`)) return

  const option = document.createElement("option")
  option.value = id
  option.textContent = label
  // Mêmes données que les options rendues par le serveur (cf. le helper
  // ingredient_option_data) : ingredient-unit y lit les unités saisissables de
  // l'ingrédient choisi, sa pièce comprise, et de quoi les convertir.
  Object.assign(option.dataset, {
    unit: baseUnit,
    unitGroup: unitGroup,
    pieceLabel: pieceLabel ?? '',
    pieceWeight: pieceWeight ?? '',
    pieceVolume: pieceVolume ?? ''
  })

  // insertBefore(option, null) revient à ajouter en fin de liste : un ingrédient
  // qui n'a pas de successeur alphabétique ferme la liste.
  const successor = Array.from(select.querySelectorAll(INGREDIENT_OPTIONS))
    .find((existing) => existing.textContent.localeCompare(label, "fr", { sensitivity: "base" }) > 0)

  select.insertBefore(option, successor || null)
}

// Pose une ligne d'ingrédient au bas du formulaire, et la rend.
//
// `quantity` et `unit` sont lues par ingredient-unit à sa connexion, c'est-à-dire
// à l'insertion : c'est lui qui remplit la quantité, choisit l'unité et en dérive
// la quantité de base soumise. Laissées vides, la ligne s'ouvre sur l'unité de
// base de l'ingrédient et sans quantité — ce qu'on veut d'un ingrédient qu'on
// vient de créer et dont on ne sait pas encore combien il en faut.
export function appendPreparationRow({ ingredientId, quantity, unit } = {}) {
  const container = document.querySelector(CONTAINER_SELECTOR)
  const template = rowTemplate()
  if (!container || !template) return null

  const fields = buildFields(template)
  if (ingredientId) ingredientSelect(fields).value = ingredientId
  if (quantity) fields.dataset.ingredientUnitQuantityValue = quantity
  if (unit) fields.dataset.ingredientUnitUnitValue = unit

  container.appendChild(fields)

  return fields
}
