import { Controller } from "@hotwired/stimulus"

// Table de conversion identique à UnitConversionService côté Ruby.
// L'absence d'unité y est une entrée à part entière : « 3 oeufs » se compte.
const NO_UNIT = { group: 'count', factor: 1 }

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

// Délai avant d'interroger le catalogue, le temps que la frappe se pose
const SEARCH_DEBOUNCE_MS = 200

// Même arrondi que côté Ruby : les quantités de base vivent au millième
const round3 = (value) => Math.round(value * 1000) / 1000

export default class extends Controller {
  static targets = ["row", "fuzzyOptions", "noMatchFallback", "search", "searchInput", "searchResults"]
  // mismatchTitle vient du serveur : la même phrase habille les suggestions
  // rendues en HAML et celles que ce contrôleur pose après une recherche.
  static values = { searchUrl: String, mismatchTitle: String }

  connect() {
    this._onIngredientCreated = this.onIngredientCreated.bind(this)
    document.addEventListener('easymeal:ingredientCreated', this._onIngredientCreated)
  }

  disconnect() {
    document.removeEventListener('easymeal:ingredientCreated', this._onIngredientCreated)
    clearTimeout(this.searchTimer)
  }

  // Ajoute un ingrédient (match exact) dans le formulaire de préparations.
  // Sa quantité est déjà convertie côté serveur, l'ingrédient étant connu — y
  // compris le verdict de cette conversion, que le badge de fin reprend.
  add(event) {
    const btn = event.currentTarget
    const { aiPanelIngredientId, aiPanelIngredientName, aiPanelBaseUnit,
            aiPanelQuantityBase, aiPanelConverted } = btn.dataset
    this.addPreparationRow(aiPanelIngredientId, aiPanelIngredientName, aiPanelBaseUnit, parseFloat(aiPanelQuantityBase) || 1)
    this.markDone(this.rowOf(btn), aiPanelConverted === 'true')
  }

  // Confirme un match approximatif proposé par le serveur
  confirmFuzzy(event) {
    this.associateFromButton(event.currentTarget)
  }

  // Retient un ingrédient choisi à la main dans le catalogue
  chooseExisting(event) {
    this.associateFromButton(event.currentTarget)
  }

  // Rejette toutes les suggestions floues → affiche les actions de repli
  rejectFuzzy(event) {
    const row = this.rowOf(event.currentTarget)
    const fuzzyOptions = row.querySelector('[data-ai-panel-target="fuzzyOptions"]')
    const noMatchFallback = row.querySelector('[data-ai-panel-target="noMatchFallback"]')
    if (fuzzyOptions) fuzzyOptions.hidden = true
    if (noMatchFallback) noMatchFallback.hidden = false
  }

  // Ouvre la recherche manuelle de la ligne, en refermant celle déjà ouverte
  // ailleurs : une seule à la fois, donc un seul debounce à gérer.
  openSearch(event) {
    const row = this.rowOf(event.currentTarget)
    const search = row.querySelector('[data-ai-panel-target="search"]')
    this.searchTargets.forEach((other) => { if (other !== search) other.hidden = true })
    search.hidden = false
    // Une seule recherche ouverte, donc un seul bouton à qui rendre le focus
    this.searchTrigger = event.currentTarget

    const input = search.querySelector('[data-ai-panel-target="searchInput"]')
    input.focus()
    input.select()
    this.runSearch(row)
  }

  // Referme la recherche sans rien choisir (croix ou Échap) et rend le focus au
  // bouton qui l'avait ouverte, sinon il resterait dans le vide.
  closeSearch(event) {
    const search = this.rowOf(event.currentTarget)?.querySelector('[data-ai-panel-target="search"]')
    if (search) search.hidden = true
    clearTimeout(this.searchTimer)
    this.searchTrigger?.focus()
    this.searchTrigger = null
  }

  // Interroge le catalogue après une pause dans la frappe
  searchCatalog(event) {
    const row = this.rowOf(event.currentTarget)
    clearTimeout(this.searchTimer)
    this.searchTimer = setTimeout(() => this.runSearch(row), SEARCH_DEBOUNCE_MS)
  }

  // Ouvre le slideout pour créer un ingrédient, pré-remplit le nom IA
  openCreate(event) {
    this.pendingRow = this.rowOf(event.currentTarget)

    // Passe par slideout#open plutôt que d'ouvrir le panneau à la main : c'est
    // lui, et lui seul, qui remet le formulaire à neuf. Sans ça, la deuxième
    // création rouvre le panneau avec le rayon, le groupe d'unités et les
    // options avancées de l'ingrédient précédent.
    this.dispatch("openIngredientForm")

    // Après la réinitialisation seulement : le champ vient d'être recréé.
    const nameInput = document.querySelector('#quick-ingredient-form input[name="ingredient[name]"]')
    if (nameInput) nameInput.value = this.pendingRow.dataset.aiPanelName || ''
  }

  // Réagit à la création d'un ingrédient via le slideout (si ouvert depuis le panneau IA)
  onIngredientCreated(event) {
    if (!this.pendingRow) return
    // Revendique la création : c'est ce panneau qui pose la ligne, avec la
    // quantité détectée par l'IA. ingredient-created ne doit donc pas
    // présélectionner l'ingrédient dans la ligne vide du formulaire.
    event.preventDefault()

    const { id, displayName, baseUnit, unitGroup, pieceWeight } = event.detail

    const quantity = this.quantityFor(this.pendingRow, unitGroup, pieceWeight)
    this.addPreparationRow(id, displayName, baseUnit, quantity.value)
    this.markDone(this.pendingRow, quantity.converted)
    this.forgetPending()
  }

  // Oublie la ligne en attente : le slideout s'est refermé sans création.
  // Sans ça, un ingrédient créé plus tard par le bouton du bas de formulaire
  // serait posé avec la quantité de la ligne abandonnée.
  forgetPending() {
    this.pendingRow = null
  }

  // === Association d'une ligne à un ingrédient existant ===

  // Suggestion confirmée et choix manuel suivent le même chemin : les deux
  // boutons portent les mêmes données, seule leur provenance diffère.
  associateFromButton(btn) {
    const row = this.rowOf(btn)
    const { aiPanelIngredientId, aiPanelIngredientName, aiPanelBaseUnit,
            aiPanelUnitGroup, aiPanelPieceWeight, aiPanelAddAliasPath } = btn.dataset

    btn.disabled = true

    this.rememberAlias(aiPanelAddAliasPath, row.dataset.aiPanelName)
      .then(() => {
        const quantity = this.quantityFor(row, aiPanelUnitGroup, aiPanelPieceWeight)
        this.addPreparationRow(aiPanelIngredientId, aiPanelIngredientName, aiPanelBaseUnit,
                               quantity.value)
        this.markDone(row, quantity.converted)
      })
      .catch(() => { btn.disabled = false })
  }

  // Mémorise le nom détecté par l'IA comme alias de l'ingrédient retenu : le
  // prochain import qui parlera de « brin de thym » retrouvera « Thym frais »
  // tout seul, sans reposer la question.
  rememberAlias(path, alias) {
    const csrfToken = document.querySelector('meta[name="csrf-token"]')?.content
    return fetch(path, {
      method: 'PATCH',
      headers: { 'Content-Type': 'application/json', 'X-CSRF-Token': csrfToken },
      body: JSON.stringify({ alias })
    })
  }

  // === Recherche dans le catalogue ===

  runSearch(row) {
    const input = row.querySelector('[data-ai-panel-target="searchInput"]')
    const results = row.querySelector('[data-ai-panel-target="searchResults"]')
    // Une frappe rapide enchaîne les requêtes : seule la dernière lancée compte,
    // les réponses arrivées dans le désordre sont ignorées.
    const requestId = (this.searchRequestId || 0) + 1
    this.searchRequestId = requestId

    const url = `${this.searchUrlValue}?q=${encodeURIComponent(input.value.trim())}`
    fetch(url, { headers: { 'Accept': 'application/json' } })
      .then((response) => response.json())
      .then((ingredients) => {
        if (requestId === this.searchRequestId) this.renderResults(row, results, ingredients)
      })
      .catch(() => this.renderMessage(results, 'Recherche indisponible'))
  }

  renderResults(row, container, ingredients) {
    if (ingredients.length === 0) {
      this.renderMessage(container, 'Aucun ingrédient ne correspond')
      return
    }

    // append de nœuds et non innerHTML : les noms viennent de la base
    container.replaceChildren(...ingredients.map((ingredient) => {
      const button = document.createElement('button')
      button.type = 'button'
      button.className = 'ai-row__search-item'
      button.append(`${ingredient.name} `, this.unitBadge(row, ingredient))
      Object.assign(button.dataset, {
        action: 'click->ai-panel#chooseExisting',
        aiPanelIngredientId: ingredient.id,
        aiPanelIngredientName: ingredient.name,
        aiPanelBaseUnit: ingredient.base_unit,
        aiPanelUnitGroup: ingredient.unit_group,
        aiPanelPieceWeight: ingredient.piece_weight_g ?? '',
        aiPanelAddAliasPath: ingredient.add_alias_path
      })
      return button
    }))
  }

  // Pendant JS du partial recipes/_ai_unit_badge : l'unité de base suit le nom,
  // et passe en alerte quand la quantité détectée sur la ligne ne sait pas la
  // rejoindre. Même classe, même phrase, des deux côtés.
  unitBadge(row, ingredient) {
    const badge = document.createElement('span')
    badge.textContent = `(${ingredient.base_unit})`

    const converts = this.convertQuantity(1, row.dataset.aiPanelUnit,
                                          ingredient.unit_group, ingredient.piece_weight_g) !== null
    badge.className = converts ? 'ai-row__unit' : 'ai-row__unit ai-row__unit--mismatch'
    if (!converts) badge.title = this.mismatchTitleValue

    return badge
  }

  renderMessage(container, text) {
    const message = document.createElement('p')
    message.className = 'ai-row__search-empty'
    message.textContent = text
    container.replaceChildren(message)
  }

  // === Pose de la ligne dans le formulaire ===

  // La quantité détectée est brute (« 1 kg », « 2 tranches ») : on la convertit
  // vers l'unité de base de l'ingrédient retenu. Conversion impossible → on
  // garde le nombre tel quel et on le signale : { value, converted }.
  quantityFor(row, unitGroup, pieceWeight) {
    const quantity = parseFloat(row.dataset.aiPanelQuantity) || 1
    const converted = this.convertQuantity(quantity, row.dataset.aiPanelUnit, unitGroup, pieceWeight)
    return converted !== null
      ? { value: converted, converted: true }
      : { value: quantity, converted: false }
  }

  // Convertit qty depuis fromUnit vers le group de l'ingrédient cible.
  // Retourne null si la conversion est impossible (unités incompatibles).
  convertQuantity(qty, fromUnit, toGroup, pieceWeight) {
    const conv = (fromUnit || '').trim() === ''
      ? NO_UNIT
      : UNIT_CONVERSIONS[fromUnit.toLowerCase().trim()]
    if (!conv) return null

    const amount = qty * conv.factor
    if (conv.group === toGroup) return round3(amount)

    return this.bridgeByPieceWeight(amount, conv.group, toGroup, pieceWeight)
  }

  // Pont pièce ↔ masse par le poids unitaire de l'ingrédient, mirroir de
  // UnitConversionService.bridge_by_piece_weight : « 2 tranches » de jambon
  // deviennent 80 g si le catalogue sait qu'une tranche pèse 40 g, et rien du
  // tout s'il l'ignore.
  bridgeByPieceWeight(amount, fromGroup, toGroup, pieceWeight) {
    const weight = parseFloat(pieceWeight)
    if (!(weight > 0)) return null

    if (fromGroup === 'count' && toGroup === 'mass') return round3(amount * weight)
    if (fromGroup === 'mass' && toGroup === 'count') return round3(amount / weight)
    return null
  }

  rowOf(element) {
    return element.closest('[data-ai-panel-target="row"]')
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

  // Remplace le contenu droit de la ligne par le badge "✓ Ajouté". Une quantité
  // que la conversion n'a pas su traduire est posée telle quelle dans le
  // formulaire : le badge le dit, sinon l'écart disparaîtrait avec la ligne.
  markDone(row, converted = true) {
    if (!row) return
    row.classList.add('ai-row--done')

    const search = row.querySelector('[data-ai-panel-target="search"]')
    if (search) search.hidden = true

    const rightSide = row.querySelector('.ai-row__right')
    if (!rightSide) return

    const badge = document.createElement('span')
    badge.className = converted ? 'ai-row__done-badge' : 'ai-row__done-badge ai-row__done-badge--warn'
    badge.textContent = converted ? '✓ Ajouté' : '✓ Ajouté — quantité à vérifier'
    if (!converted) badge.title = this.mismatchTitleValue
    rightSide.replaceChildren(badge)
  }
}
