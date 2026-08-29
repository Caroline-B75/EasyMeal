import { Controller } from "@hotwired/stimulus"
import { registerIngredient, appendPreparationRow, preparationRows, ingredientSelect } from "preparation_rows"

// Controller pour gérer l'événement de création d'un ingrédient
// Inscrit l'ingrédient au catalogue, l'ajoute à la recette en cours, affiche un
// flash message et ferme le slideout
export default class extends Controller {
  static values = {
    id: Number,
    // Nom seul, pour le message de confirmation.
    name: String,
    // Libellé de l'option du sélecteur d'ingrédient, unité comprise, composé
    // par Ingredient#select_label : l'option ajoutée ici doit se lire et se
    // trier exactement comme celles rendues par le serveur.
    optionLabel: String,
    baseUnit: String,
    unitGroup: String,
    // Absents quand l'ingrédient ne porte pas ce coefficient : Stimulus rend
    // alors 0, que le panneau IA lit comme « pas de pont » — de pièce à masse
    // pour le poids unitaire, de volume à masse pour la densité.
    pieceWeight: Number,
    density: Number,
    // « ai » quand la densité n'est qu'une estimation : le panneau le signale.
    densitySource: String
  }

  connect() {
    // Le catalogue d'abord, l'événement ensuite : ceux qui posent une ligne en
    // réponse la clonent du modèle, et ils la veulent déjà garnie.
    registerIngredient({ id: this.idValue, label: this.optionLabelValue,
                         baseUnit: this.baseUnitValue, unitGroup: this.unitGroupValue })

    // Notifie les autres controllers (ex: ai-panel). Celui qui prend en charge
    // le nouvel ingrédient annule l'événement : il pose lui-même la ligne, avec
    // la quantité détectée par l'IA. Sans cette revendication, l'ajout
    // ci-dessous garnirait en plus la ligne vide du formulaire —
    // le même ingrédient en double, et celui-là sans quantité.
    // Le détail se limite à ce qui sert à convertir une quantité : le libellé,
    // lui, est déjà au catalogue, où le repreneur ira le chercher.
    const claimed = !document.dispatchEvent(new CustomEvent('easymeal:ingredientCreated', {
      bubbles: true,
      cancelable: true,
      detail: {
        id: this.idValue,
        baseUnit: this.baseUnitValue,
        unitGroup: this.unitGroupValue,
        pieceWeight: this.pieceWeightValue,
        density: this.densityValue,
        densitySource: this.densitySourceValue
      }
    }))

    if (!claimed) this.addToRecipe()
    this.showFlashMessage()
    this.closeSlideout()
    setTimeout(() => this.element.remove(), 100)
  }

  // L'ingrédient créé rejoint la recette en cours, sans quantité : la ligne
  // vide qui attend, ou une ligne de plus s'il n'y en a aucune. On vient de le
  // décrire en entier, le retrouver à la main dans une liste de 600 entrées
  // serait une deuxième corvée pour rien.
  addToRecipe() {
    // Une ligne masquée est une ligne marquée pour suppression : elle n'attend
    // plus rien.
    const row = preparationRows().find((fields) => !fields.hidden && !ingredientSelect(fields).value)
    if (!row) {
      appendPreparationRow({ ingredientId: this.idValue })
      return
    }

    const select = ingredientSelect(row)
    select.value = this.idValue
    // ingredient-unit est déjà connecté sur cette ligne : c'est ce change qui
    // lui fait relire l'ingrédient et proposer ses unités.
    select.dispatchEvent(new Event('change', { bubbles: true }))
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
