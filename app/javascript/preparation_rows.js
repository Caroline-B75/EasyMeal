import { TEMPLATE_SELECTOR, CONTAINER_SELECTOR, FIELDS_SELECTOR, buildFields } from "nested_fields"

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

// Inscrit un ingrédient tout juste créé dans le catalogue et dans les lignes déjà
// à l'écran, à sa place alphabétique. Le catalogue d'abord : c'est de lui que
// seront clonées les lignes suivantes.
export function registerIngredient(ingredient) {
  const catalog = catalogSelect()
  const selects = [ ...(catalog ? [ catalog ] : []), ...document.querySelectorAll(INGREDIENT_SELECT) ]

  selects.forEach((select) => insertOption(select, ingredient))
}

function insertOption(select, { id, label, baseUnit, unitGroup }) {
  if (select.querySelector(`option[value="${CSS.escape(String(id))}"]`)) return

  const option = document.createElement("option")
  option.value = id
  option.textContent = label
  // Mêmes données que les options rendues par le serveur : ingredient-unit y lit
  // les unités saisissables de l'ingrédient choisi.
  option.dataset.unit = baseUnit
  option.dataset.unitGroup = unitGroup

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
