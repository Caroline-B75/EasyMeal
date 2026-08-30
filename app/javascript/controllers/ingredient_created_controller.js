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
    pieceVolume: Number,
    // Le nom de la pièce, quand cet ingrédient s'achète à la pièce : il décide
    // de l'unité que le formulaire proposera en plus de la mesure.
    pieceLabel: String,
    density: Number,
    // « ai » quand la densité n'est qu'une estimation : le panneau le signale.
    densitySource: String
  }

  connect() {
    // Le catalogue d'abord, l'événement ensuite : ceux qui posent une ligne en
    // réponse la clonent du modèle, et ils la veulent déjà garnie.
    registerIngredient({ id: this.idValue, label: this.optionLabelValue,
                         baseUnit: this.baseUnitValue, unitGroup: this.unitGroupValue,
                         pieceLabel: this.pieceLabelValue, pieceWeight: this.pieceWeightValue,
                         pieceVolume: this.pieceVolumeValue })

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
        pieceVolume: this.pieceVolumeValue,
        density: this.densityValue,
        densitySource: this.densitySourceValue
      }
    }))

    if (!claimed) this.addToRecipe()
    this.showFlashMessage()
    this.closeSlideout()
    setTimeout(() => this.element.remove(), 100)
  }

  // L'ingrédient créé rejoint la recette en cours, sans quantité : on vient de
  // le décrire en entier, le retrouver à la main dans une liste de 600 entrées
  // serait une deuxième corvée pour rien.
  //
  // Il se pose toujours au bas de la liste, là où le bouton « Ajouter un
  // ingrédient » pose la sienne : la ligne vide qui la termine si elle attend,
  // une ligne de plus sinon. Une ligne vide plus haut n'est pas reprise — le
  // formulaire d'un brouillon IA en ouvre une avant que le panneau ne pose ses
  // ingrédients en dessous, et le nouvel ingrédient atterrissait alors tout en
  // haut, loin du geste qui venait de le créer.
  addToRecipe() {
    // Une ligne masquée est une ligne marquée pour suppression : elle n'attend
    // plus rien.
    const rows = preparationRows().filter((fields) => !fields.hidden)
    const select = rows.length ? ingredientSelect(rows[rows.length - 1]) : null

    if (!select || select.value) {
      appendPreparationRow({ ingredientId: this.idValue })
      return
    }

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
