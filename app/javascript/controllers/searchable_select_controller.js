import { Controller } from "@hotwired/stimulus"

// Controller de recherche native pour les selects d'ingrédients.
// Remplace jQuery + Select2 par du JavaScript pur : un champ de recherche
// filtre les options via `option.hidden` sans manipuler le DOM.
export default class extends Controller {
  static targets = ["select"]

  connect() {
    this.buildSearchInput()
  }

  disconnect() {
    this.searchInput?.remove()
  }

  buildSearchInput() {
    this.searchInput = document.createElement('input')
    this.searchInput.type = 'text'
    this.searchInput.placeholder = 'Rechercher un ingrédient...'
    this.searchInput.className = 'form-input searchable-select-input'
    this.searchInput.setAttribute('autocomplete', 'off')

    this.selectTarget.insertAdjacentElement('beforebegin', this.searchInput)
    this.searchInput.addEventListener('input', () => this.filterOptions())
  }

  filterOptions() {
    const query = this.searchInput.value.toLowerCase().trim()

    Array.from(this.selectTarget.options).forEach(option => {
      // Toujours garder l'option placeholder vide
      if (option.value === '') return
      option.hidden = query.length > 0 && !option.text.toLowerCase().includes(query)
    })
  }
}
