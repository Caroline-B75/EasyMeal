import { Controller } from "@hotwired/stimulus"

// Table de conversion identique à UnitConversionService côté Ruby
const UNIT_CONVERSIONS = {
  g:       { group: 'mass',   factor: 1 },
  kg:      { group: 'mass',   factor: 1000 },
  ml:      { group: 'volume', factor: 1 },
  cl:      { group: 'volume', factor: 10 },
  dl:      { group: 'volume', factor: 100 },
  l:       { group: 'volume', factor: 1000 },
  'càc':   { group: 'spoon',  factor: 1 },
  cac:     { group: 'spoon',  factor: 1 },
  'càs':   { group: 'spoon',  factor: 3 },
  cas:     { group: 'spoon',  factor: 3 },
  piece:   { group: 'count',  factor: 1 },
  'pièce': { group: 'count',  factor: 1 },
  'pièces':{ group: 'count',  factor: 1 },
}

export default class extends Controller {
  static targets = ["row", "fuzzyOptions", "noMatchFallback"]

  connect() {
    this._onIngredientCreated = this.onIngredientCreated.bind(this)
    document.addEventListener('easymeal:ingredientCreated', this._onIngredientCreated)
  }

  disconnect() {
    document.removeEventListener('easymeal:ingredientCreated', this._onIngredientCreated)
  }

  // Ajoute un ingrédient (match exact) dans le formulaire de préparations
  add(event) {
    const btn = event.currentTarget
    const row = btn.closest('[data-ai-panel-target="row"]')
    const { aiPanelIngredientId, aiPanelIngredientName, aiPanelBaseUnit, aiPanelQuantityBase } = btn.dataset
    this.addPreparationRow(aiPanelIngredientId, aiPanelIngredientName, aiPanelBaseUnit, parseFloat(aiPanelQuantityBase) || 1)
    this.markDone(row)
  }

  // Confirme un match approximatif : enregistre l'alias puis ajoute au formulaire
  confirmFuzzy(event) {
    const btn = event.currentTarget
    // Capturer la référence à la ligne AVANT l'appel async
    const row = btn.closest('[data-ai-panel-target="row"]')
    const { aiPanelIngredientId, aiPanelIngredientName, aiPanelBaseUnit,
            aiPanelQuantityBase, aiPanelAlias, aiPanelAddAliasPath } = btn.dataset

    btn.disabled = true

    const csrfToken = document.querySelector('meta[name="csrf-token"]')?.content
    fetch(aiPanelAddAliasPath, {
      method: 'PATCH',
      headers: { 'Content-Type': 'application/json', 'X-CSRF-Token': csrfToken },
      body: JSON.stringify({ alias: aiPanelAlias })
    })
    .then(() => {
      this.addPreparationRow(aiPanelIngredientId, aiPanelIngredientName, aiPanelBaseUnit, parseFloat(aiPanelQuantityBase) || 1)
      this.markDone(row)
    })
    .catch(() => { btn.disabled = false })
  }

  // Rejette toutes les suggestions floues → affiche le bouton "Créer"
  rejectFuzzy(event) {
    const row = event.currentTarget.closest('[data-ai-panel-target="row"]')
    const fuzzyOptions = row.querySelector('[data-ai-panel-target="fuzzyOptions"]')
    const noMatchFallback = row.querySelector('[data-ai-panel-target="noMatchFallback"]')
    if (fuzzyOptions) fuzzyOptions.hidden = true
    if (noMatchFallback) noMatchFallback.hidden = false
  }

  // Ouvre le slideout pour créer un ingrédient, pré-remplit le nom IA
  openCreate(event) {
    const btn = event.currentTarget
    this.pendingRow = btn.closest('[data-ai-panel-target="row"]')
    this.pendingQuantity = parseFloat(btn.dataset.aiPanelQuantityBase) || 1
    this.pendingUnit = btn.dataset.aiPanelUnit || null

    const nameInput = document.querySelector('#quick-ingredient-form input[name="ingredient[name]"]')
    if (nameInput) nameInput.value = btn.dataset.aiPanelName || ''

    const slideoutPanel = document.querySelector('.slideout-panel')
    const slideoutOverlay = document.querySelector('.slideout-overlay')
    if (slideoutPanel) slideoutPanel.classList.add('open')
    if (slideoutOverlay) slideoutOverlay.classList.add('open')
    document.body.style.overflow = 'hidden'
  }

  // Réagit à la création d'un ingrédient via le slideout (si ouvert depuis le panneau IA)
  onIngredientCreated(event) {
    if (!this.pendingRow) return
    const { id, displayName, baseUnit, unitGroup } = event.detail

    // Convertir la quantité IA vers la base_unit du nouvel ingrédient (ex: 1 kg → 1000 g)
    const rawQty = this.pendingQuantity || 1
    const converted = this.convertQuantity(rawQty, this.pendingUnit, unitGroup)
    const finalQty = converted !== null ? converted : rawQty

    this.addPreparationRow(id, displayName, baseUnit, finalQty)
    this.markDone(this.pendingRow)
    this.pendingRow = null
    this.pendingQuantity = null
    this.pendingUnit = null
  }

  // Convertit qty depuis fromUnit vers le group de l'ingrédient cible.
  // Retourne null si la conversion est impossible (unités incompatibles).
  convertQuantity(qty, fromUnit, toGroup) {
    if (!fromUnit) return null
    const conv = UNIT_CONVERSIONS[(fromUnit || '').toLowerCase().trim()]
    if (!conv || conv.group !== toGroup) return null
    return Math.round(qty * conv.factor * 1000) / 1000
  }

  // Clone le template nested-form, configure ingrédient + quantité, appende au container
  addPreparationRow(ingredientId, ingredientName, baseUnit, quantityBase) {
    const template = document.querySelector('[data-nested-form-target="template"]')
    const container = document.querySelector('[data-nested-form-target="container"]')
    if (!template || !container) return

    const timestamp = new Date().getTime()
    const html = template.innerHTML.replace(/NEW_RECORD/g, timestamp)
    const tmp = document.createElement('div')
    tmp.innerHTML = html.trim()
    const row = tmp.firstElementChild

    const select = row.querySelector('select[name*="ingredient_id"]')
    if (select) {
      if (!select.querySelector(`option[value="${ingredientId}"]`)) {
        const option = document.createElement('option')
        option.value = ingredientId
        option.textContent = ingredientName
        option.dataset.unit = baseUnit
        select.appendChild(option)
      }
      select.value = ingredientId
    }

    const qtyInput = row.querySelector('input[name*="quantity_base"]')
    if (qtyInput) qtyInput.value = quantityBase

    container.appendChild(row)
    if (select) select.dispatchEvent(new Event('change', { bubbles: true }))
  }

  // Remplace le contenu droit de la ligne par le badge "✓ Ajouté"
  markDone(row) {
    if (!row) return
    row.classList.add('ai-row--done')
    const rightSide = row.querySelector('.ai-row__right')
    if (rightSide) rightSide.innerHTML = '<span class="ai-row__done-badge">✓ Ajouté</span>'
  }
}
