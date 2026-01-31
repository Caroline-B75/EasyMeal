// Controller Stimulus pour l'édition inline des tags
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["display", "form", "input"]

  // Activer le mode édition
  edit(event) {
    event.preventDefault()
    const row = event.currentTarget.closest("tr")
    row.classList.add("editing")
    
    const displayElement = row.querySelector("[data-tag-inline-target='display']")
    const formElement = row.querySelector("[data-tag-inline-target='form']")
    
    displayElement.style.display = "none"
    formElement.style.display = "flex"
    
    // Focus sur l'input
    const input = formElement.querySelector("input")
    input.focus()
    input.select()
  }

  // Annuler l'édition
  cancel(event) {
    event.preventDefault()
    const row = event.currentTarget.closest("tr")
    this.resetRow(row)
  }

  // Réinitialiser l'affichage d'une ligne
  resetRow(row) {
    row.classList.remove("editing")
    const displayElement = row.querySelector("[data-tag-inline-target='display']")
    const formElement = row.querySelector("[data-tag-inline-target='form']")
    
    displayElement.style.display = "flex"
    formElement.style.display = "none"
  }
}
