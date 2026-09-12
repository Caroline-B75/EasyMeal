import { Controller } from "@hotwired/stimulus"
import { buildFields, removeFields } from "nested_fields"

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
 * Les deux champs cachés d'une ligne sont lus par le module nested_fields, qui
 * porte la convention et la règle de retrait — ce contrôleur n'en est qu'un des
 * usagers, avec le panneau d'import et la restauration d'une saisie.
 */
export default class extends Controller {
  static targets = ["container", "template", "fields"]

  /**
   * Ajoute un nouveau champ depuis le template
   */
  add(event) {
    event.preventDefault()

    this.containerTarget.appendChild(buildFields(this.templateTarget))
  }

  /**
   * Supprime le champ d'où part le clic.
   */
  remove(event) {
    event.preventDefault()

    const fields = this.fieldsTargets.find((element) => element.contains(event.target))
    if (fields) removeFields(fields)
  }
}
