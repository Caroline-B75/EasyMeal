import { Controller } from "@hotwired/stimulus"
import { readSnapshot, writeSnapshot, forgetSnapshot } from "form_snapshot"
import { readImageUrl, assignFile } from "photo_input"
import { FIELDS_SELECTOR, DESTROY_SELECTOR } from "nested_fields"
import { appendPreparationRow, preparationRows, ingredientSelect } from "preparation_rows"

// Retient la saisie en cours du formulaire de recette, et la repose si la page
// est rechargée. Le formulaire est long — nom, caractéristiques, photo, lignes
// d'ingrédients, étapes, tags — et un rechargement le vidait entièrement.
//
// L'instantané est repris à chaque interaction, puis marqué « soumis » au départ
// du formulaire. C'est ce marquage qui distingue les trois façons de revenir sur
// la page :
//   - instantané vif              → la page a été rechargée en cours de saisie :
//                                   on repose tout
//   - marqué + formulaire refusé  → la sauvegarde a échoué : le serveur a
//                                   ré-affiché la saisie, seule la photo manque
//   - marqué + formulaire accepté → la recette est enregistrée : on oublie
//
// Le pari du repérage : chaque contrôle est retrouvé par son nom, jamais par sa
// position. Deux rendus successifs de la même page ne se ressemblent pas
// forcément — le panneau d'import IA, par exemple, change avec le catalogue
// d'ingrédients.

// Le temps qu'une frappe se pose : reprendre l'instantané à chaque caractère
// sérialiserait le formulaire entier pour rien.
const SNAPSHOT_DEBOUNCE_MS = 300

// Plomberie de Rails et boutons : rien qui appartienne à la saisie.
const IGNORED_NAMES = [ "authenticity_token", "_method" ]
const IGNORED_TYPES = [ "submit", "button", "reset", "file" ]

// Ce qu'une ligne d'ingrédient donne à lire. La quantité de base soumise n'y
// figure pas : ingredient-unit la recalcule de ce qui s'affiche, la retenir
// serait la retenir deux fois.
const QUANTITY_FIELD = '[data-ingredient-unit-target="quantity"]'
const UNIT_FIELD = '[data-ingredient-unit-target="unit"]'

const isToggle = (field) => field.type === "checkbox" || field.type === "radio"

// Cases et boutons radio se partagent un nom — cinq cases pour
// `recipe[meal_types][]` — et se distinguent par la valeur qu'ils portent.
const fieldKey = (field) => (isToggle(field) ? `${field.name}=${field.value}` : field.name)
const fieldValue = (field) => (isToggle(field) ? field.checked : field.value)

function applyFieldValue(field, value) {
  if (isToggle(field)) field.checked = value
  else field.value = value
}

function rowSnapshot(row) {
  return {
    ingredientId: ingredientSelect(row)?.value || "",
    quantity: row.querySelector(QUANTITY_FIELD)?.value || "",
    unit: row.querySelector(UNIT_FIELD)?.value || "",
    destroyed: row.querySelector(DESTROY_SELECTOR)?.value === "1"
  }
}

// Repose une ligne déjà à l'écran. L'ordre compte : ingredient-unit reconstruit
// le sélecteur d'unités au changement d'ingrédient, on ne peut donc y choisir
// l'unité retenue qu'après.
function applyRow(row, { ingredientId, quantity, unit, destroyed }) {
  const select = ingredientSelect(row)
  if (select && select.value !== ingredientId) {
    select.value = ingredientId
    select.dispatchEvent(new Event("change", { bubbles: true }))
  }

  const unitField = row.querySelector(UNIT_FIELD)
  const quantityField = row.querySelector(QUANTITY_FIELD)
  if (unitField) unitField.value = unit
  if (quantityField) {
    quantityField.value = quantity
    // Remet la quantité soumise en accord avec ce qui s'affiche.
    quantityField.dispatchEvent(new Event("input", { bubbles: true }))
  }

  if (!destroyed) return

  // Même geste que nested-form#remove : la ligne reste soumise, marquée pour
  // suppression, mais disparaît de l'écran.
  row.querySelector(DESTROY_SELECTOR).value = "1"
  row.hidden = true
}

export default class extends Controller {
  static values = {
    // Le serveur a-t-il refusé cette soumission ? Vrai sur le seul ré-affichage
    // qui suit une validation en échec.
    rejected: Boolean
  }

  connect() {
    // La restauration attend que Stimulus ait connecté tout le formulaire :
    // c'est ingredient-options qui garnit les sélecteurs des lignes rendues par
    // le serveur, et on ne peut y choisir un ingrédient qu'après lui.
    requestAnimationFrame(() => this.recover())
  }

  disconnect() {
    clearTimeout(this.timer)
  }

  // Toute interaction peut modifier le formulaire : une frappe change un champ,
  // un clic ajoute ou retire une ligne d'ingrédient.
  schedule() {
    clearTimeout(this.timer)
    this.timer = setTimeout(() => this.write(this.snapshot()), SNAPSHOT_DEBOUNCE_MS)
  }

  // La photo retenue par le champ, annoncée par image-preview : lui seul sait
  // quand la version réduite a remplacé l'originale, et c'est elle qu'il faut
  // encoder — celle qui sort d'un téléphone dépasserait le quota à elle seule.
  // Relue à ce moment-là et à ce moment-là seulement : encoder une image à
  // chaque frappe coûterait cher pour rien.
  photoReady({ detail: { file } }) {
    readImageUrl(file).then((dataUrl) => {
      this.photo = dataUrl ? { name: file.name, type: file.type, dataUrl: dataUrl } : null
      this.write(this.snapshot())
    })
  }

  // Départ du formulaire : l'instantané ne sert plus qu'à rattraper une
  // sauvegarde refusée, dont seule la photo échappe au ré-affichage du serveur.
  markSubmitted() {
    clearTimeout(this.timer)
    this.write({ submitted: true, photo: this.photo })
  }

  // === Écriture ===

  snapshot() {
    return {
      submitted: false,
      fields: Object.fromEntries(this.fields().map((field) => [ fieldKey(field), fieldValue(field) ])),
      preparations: preparationRows().map(rowSnapshot),
      photo: this.photo || null
    }
  }

  // Le quota du sessionStorage se compte en méga-octets : une photo encodée peut
  // le dépasser à elle seule. Le texte de la recette vaut plus qu'elle : on la
  // laisse tomber plutôt que de perdre l'instantané entier.
  write(snapshot) {
    if (writeSnapshot(this.key, snapshot)) return

    writeSnapshot(this.key, { ...snapshot, photo: null })
  }

  // === Restauration ===

  recover() {
    const snapshot = readSnapshot(this.key)
    if (!snapshot) return

    if (!snapshot.submitted) this.restore(snapshot)
    else if (this.rejectedValue) this.restorePhoto(snapshot.photo)
    else forgetSnapshot(this.key)
  }

  restore({ fields, preparations, photo }) {
    this.restorePreparations(preparations)
    this.fields().forEach((field) => {
      const value = fields[fieldKey(field)]
      if (value !== undefined) applyFieldValue(field, value)
    })
    this.restorePhoto(photo)
  }

  restorePreparations(entries) {
    const rendered = preparationRows()

    entries.forEach((entry, index) => {
      // Au-delà des lignes rendues par le serveur, la ligne est clonée du modèle :
      // ingredient-unit y lit quantité et unité en se connectant, rien à reposer.
      if (rendered[index]) applyRow(rendered[index], entry)
      else appendPreparationRow(entry)
    })

    // Lignes en trop : la saisie en avait retiré. Une ligne déjà enregistrée
    // n'est jamais retirée du DOM — nested-form la masque et la marque pour
    // suppression —, celles-ci sont donc forcément neuves.
    rendered.slice(entries.length).forEach((row) => row.remove())
  }

  // Un champ fichier ne se remplit pas au clavier : on refabrique le fichier
  // depuis l'image encodée, et image-preview refait sa mise en scène.
  restorePhoto(photo) {
    const input = this.element.querySelector('input[type="file"]')
    if (!photo || !input) return

    fetch(photo.dataUrl)
      .then((response) => response.blob())
      .then((blob) => {
        assignFile(input, new File([ blob ], photo.name, { type: photo.type }))
        this.dispatch("photoRestored", { target: input })
      })
      // Image illisible : le reste de la saisie est reposé, la photo est à
      // rechoisir — jamais une raison de laisser le formulaire vide.
      .catch(() => {})
  }

  // === Repères ===

  // Un instantané par formulaire : créer une recette et en modifier une autre
  // n'écrivent pas au même endroit.
  get key() {
    return `${this.element.method}:${this.element.action}`
  }

  // Les contrôles nommés du formulaire, hors lignes d'ingrédient — reprises à
  // part, leur nombre variant d'un rendu à l'autre.
  fields() {
    return Array.from(this.element.elements).filter((field) => (
      field.name &&
      !IGNORED_NAMES.includes(field.name) &&
      !IGNORED_TYPES.includes(field.type) &&
      !field.closest(FIELDS_SELECTOR)
    ))
  }
}
