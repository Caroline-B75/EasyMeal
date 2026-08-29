import { Controller } from "@hotwired/stimulus"

/**
 * Controller pour gérer les nested fields (ajout/suppression dynamique)
 * Utilisé pour les ingrédients dans le formulaire de recette
 *
 * Usage :
 * <div data-controller="nested-form">
 *   <template data-nested-form-target="template">...</template>
 *   <div data-nested-form-target="container">
 *     <div data-nested-form-target="fields">
 *       <input type="hidden" name="…[id]" data-nested-form-target="recordId">
 *       <input type="hidden" name="…[_destroy]" data-nested-form-target="destroy">
 *       <button data-action="click->nested-form#remove">✕</button>
 *     </div>
 *   </div>
 *   <button data-action="click->nested-form#add">Ajouter</button>
 * </div>
 *
 * recordId n'est présent que sur un enregistrement déjà en base : c'est ce qui
 * distingue une suppression côté serveur d'un simple retrait du DOM.
 */
export default class extends Controller {
  static targets = ["container", "template", "fields", "destroy", "recordId"]

  /**
   * Ajoute un nouveau champ depuis le template
   */
  add(event) {
    event.preventDefault()

    // Récupère le contenu du template
    const content = this.templateTarget.innerHTML

    // Génère un ID unique pour éviter les conflits
    const uniqueId = new Date().getTime().toString()

    // Remplace le placeholder NEW_RECORD par l'ID unique
    const newFields = content.replace(/NEW_RECORD/g, uniqueId)

    // Insère les nouveaux champs dans le container
    this.containerTarget.insertAdjacentHTML("beforeend", newFields)
  }

  /**
   * Supprime un champ : retiré du DOM s'il n'a jamais été enregistré, marqué
   * _destroy sinon (Rails ignore les enfants absents des params, donc retirer
   * le bloc ne suffirait pas à supprimer l'enregistrement).
   */
  remove(event) {
    event.preventDefault()

    const fields = this.fieldsTargets.find((element) => element.contains(event.target))
    if (!fields) return

    const persisted = this.recordIdTargets.some((element) => fields.contains(element))
    const destroyInput = this.destroyTargets.find((element) => fields.contains(element))

    if (persisted && destroyInput) {
      // Toujours soumis mais masqué : _destroy à 1 déclenche la suppression
      // à la sauvegarde du formulaire.
      destroyInput.value = "1"
      fields.hidden = true
    } else {
      fields.remove()
    }
  }
}
