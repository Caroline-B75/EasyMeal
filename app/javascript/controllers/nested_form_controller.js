import { Controller } from "@hotwired/stimulus"

/**
 * Controller pour gérer les nested fields (ajout/suppression dynamique)
 * Utilisé pour les ingrédients dans le formulaire de recette
 * 
 * Usage :
 * <div data-controller="nested-form">
 *   <template data-nested-form-target="template">...</template>
 *   <div data-nested-form-target="container">...</div>
 *   <button data-action="click->nested-form#add">Ajouter</button>
 * </div>
 */
export default class extends Controller {
  static targets = ["container", "template", "fields", "destroy"]

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
   * Supprime un champ existant (ou marque pour suppression si déjà persisté)
   */
  remove(event) {
    event.preventDefault()
    
    // Trouve le parent .nested-fields le plus proche
    const fieldsElement = event.target.closest(".nested-fields")
    
    if (fieldsElement) {
      // Marque pour suppression (enregistrement existant)
      fieldsElement.classList.add("marked-for-deletion")
      
      // Optionnel : cache visuellement le champ
      fieldsElement.style.opacity = "0.5"
      fieldsElement.style.pointerEvents = "none"
      
      // Retire complètement la div
      fieldsElement.remove()
    }
  }
}
