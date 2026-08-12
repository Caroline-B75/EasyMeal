import { Controller } from "@hotwired/stimulus"

// Controller pour gérer l'événement de création d'un ingrédient
// Met à jour tous les selects d'ingrédients, affiche un flash message et ferme le slideout
export default class extends Controller {
  static values = {
    id: Number,
    name: String,
    displayName: String,
    baseUnit: String,
    unitGroup: String,
    // Absent quand l'ingrédient n'a pas de poids unitaire : Stimulus rend alors
    // 0, que le panneau IA lit comme « pas de pont pièce ↔ masse ».
    pieceWeight: Number
  }

  connect() {
    this.updateIngredientSelects()

    // Notifie les autres controllers (ex: ai-panel). Celui qui prend en charge
    // le nouvel ingrédient annule l'événement : il pose lui-même la ligne, avec
    // la quantité détectée par l'IA. Sans cette revendication, la
    // présélection ci-dessous garnirait en plus la ligne vide du formulaire —
    // le même ingrédient en double, et celui-là sans quantité.
    const claimed = !document.dispatchEvent(new CustomEvent('easymeal:ingredientCreated', {
      bubbles: true,
      cancelable: true,
      detail: {
        id: this.idValue,
        name: this.nameValue,
        displayName: this.displayNameValue,
        baseUnit: this.baseUnitValue,
        unitGroup: this.unitGroupValue,
        pieceWeight: this.pieceWeightValue
      }
    }))

    if (!claimed) this.preselectIngredient()
    this.showFlashMessage()
    this.closeSlideout()
    setTimeout(() => this.element.remove(), 100)
  }

  updateIngredientSelects() {
    const selects = document.querySelectorAll('select[name*="ingredient_id"]')

    selects.forEach(select => {
      if (!select.querySelector(`option[value="${this.idValue}"]`)) {
        const option = document.createElement('option')
        option.value = this.idValue
        option.textContent = this.displayNameValue
        option.dataset.unit = this.baseUnitValue

        // Insertion alphabétique
        const existingOptions = Array.from(select.querySelectorAll('option'))
        const ingredientOptions = existingOptions.slice(1)

        let inserted = false
        for (const existingOption of ingredientOptions) {
          if (existingOption.textContent.localeCompare(this.displayNameValue, 'fr', { sensitivity: 'base' }) > 0) {
            select.insertBefore(option, existingOption)
            inserted = true
            break
          }
        }

        if (!inserted) {
          select.appendChild(option)
        }
      }
    })
  }

  // Présélectionne le nouvel ingrédient dans le premier select vide
  preselectIngredient() {
    const selects = document.querySelectorAll('select[name*="ingredient_id"]')
    const emptySelect = Array.from(selects).find(select => !select.value)

    if (emptySelect) {
      emptySelect.value = this.idValue
      // Déclencher l'événement change pour mettre à jour l'unité affichée
      emptySelect.dispatchEvent(new Event('change', { bubbles: true }))
    }
  }

  showFlashMessage() {
    // Trouver ou créer le container de flash messages
    let flashContainer = document.querySelector('.flash-messages')
    
    if (!flashContainer) {
      flashContainer = document.createElement('div')
      flashContainer.className = 'flash-messages'
      document.body.prepend(flashContainer)
    }
    
    // Créer le flash message
    const flashMessage = document.createElement('div')
    flashMessage.className = 'flash-message notice'
    flashMessage.setAttribute('data-controller', 'flash')
    flashMessage.innerHTML = `Ingrédient <strong>${this.nameValue}</strong> créé avec succès !`
    
    // Insérer au début du container
    flashContainer.prepend(flashMessage)
  }

  closeSlideout() {
    // Trouver et fermer le slideout
    const slideoutPanel = document.querySelector('.slideout-panel.open')
    const slideoutOverlay = document.querySelector('.slideout-overlay.open')
    
    if (slideoutPanel) {
      slideoutPanel.classList.remove('open')
    }
    if (slideoutOverlay) {
      slideoutOverlay.classList.remove('open')
    }
    
    // Réactiver le scroll
    document.body.style.overflow = ''
  }
}
