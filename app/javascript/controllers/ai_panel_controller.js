import { Controller } from "@hotwired/stimulus"
import { unitsTable, unitDefinition, unitLabel, factorTo, unitOffered } from "units"

// Délai avant d'interroger le catalogue, le temps que la frappe se pose
const SEARCH_DEBOUNCE_MS = 200

// Un ingrédient réduit à ce qui sert à convertir. Le JSON de la recherche parle
// en snake_case (c'est du Rails), les boutons et l'événement de création en
// camelCase : la traduction se fait ici, une fois pour toutes.
const coefficientsOf = (json) => ({
  unitGroup: json.unit_group,
  pieceWeight: json.piece_weight_g,
  density: json.density_g_per_ml,
  densitySource: json.density_source
})

// Même arrondi que côté Ruby : les quantités de base vivent au millième
const round3 = (value) => Math.round(value * 1000) / 1000

export default class extends Controller {
  static targets = ["row", "fuzzyOptions", "noMatchFallback", "search", "searchInput", "searchResults"]
  // Les deux phrases viennent du serveur : elles habillent aussi bien les
  // suggestions rendues en HAML que celles que ce contrôleur pose après une
  // recherche, et n'existent donc qu'une fois, dans fr.yml.
  static values = { searchUrl: String, mismatchTitle: String, estimatedTitle: String }

  connect() {
    // Groupes, facteurs et libellés viennent de Ruby (Units.table, posée sur le
    // formulaire) : ce contrôleur n'en tient aucune copie.
    this.units = unitsTable(this.element)
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
    const row = this.rowOf(btn)
    const { aiPanelIngredientId, aiPanelIngredientName, aiPanelBaseUnit, aiPanelUnitGroup,
            aiPanelQuantityBase, aiPanelConverted, aiPanelEstimated } = btn.dataset

    this.addPreparationRow({ id: aiPanelIngredientId, name: aiPanelIngredientName,
                             baseUnit: aiPanelBaseUnit, unitGroup: aiPanelUnitGroup,
                             row: row, quantityBase: parseFloat(aiPanelQuantityBase) || 1 })
    this.markDone(row, { converted: aiPanelConverted === 'true',
                         estimated: aiPanelEstimated === 'true' })
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

    const { id, displayName, baseUnit, unitGroup, pieceWeight, density, densitySource } = event.detail
    const ingredient = { unitGroup, pieceWeight, density, densitySource }

    const quantity = this.quantityFor(this.pendingRow, ingredient)
    this.addPreparationRow({ id: id, name: displayName, baseUnit: baseUnit, unitGroup: unitGroup,
                             row: this.pendingRow, quantityBase: quantity.value })
    this.markDone(this.pendingRow, { converted: quantity.converted, estimated: this.estimatedFor(this.pendingRow, ingredient) })
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
    const { aiPanelIngredientId, aiPanelIngredientName, aiPanelBaseUnit, aiPanelUnitGroup,
            aiPanelPieceWeight, aiPanelDensity, aiPanelDensitySource, aiPanelAddAliasPath } = btn.dataset
    const ingredient = { unitGroup: aiPanelUnitGroup, pieceWeight: aiPanelPieceWeight,
                         density: aiPanelDensity, densitySource: aiPanelDensitySource }

    btn.disabled = true

    this.rememberAlias(aiPanelAddAliasPath, row.dataset.aiPanelName)
      .then(() => {
        const quantity = this.quantityFor(row, ingredient)
        this.addPreparationRow({ id: aiPanelIngredientId, name: aiPanelIngredientName,
                                 baseUnit: aiPanelBaseUnit, unitGroup: aiPanelUnitGroup,
                                 row: row, quantityBase: quantity.value })
        this.markDone(row, { converted: quantity.converted, estimated: this.estimatedFor(row, ingredient) })
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
      const coefficients = coefficientsOf(ingredient)
      const button = document.createElement('button')
      button.type = 'button'
      button.className = 'ai-row__search-item'
      button.append(`${ingredient.name} `, this.unitBadge(row, ingredient.base_unit, coefficients))
      Object.assign(button.dataset, {
        action: 'click->ai-panel#chooseExisting',
        aiPanelIngredientId: ingredient.id,
        aiPanelIngredientName: ingredient.name,
        aiPanelBaseUnit: ingredient.base_unit,
        aiPanelUnitGroup: ingredient.unit_group,
        aiPanelPieceWeight: ingredient.piece_weight_g ?? '',
        aiPanelDensity: ingredient.density_g_per_ml ?? '',
        aiPanelDensitySource: ingredient.density_source ?? '',
        aiPanelAddAliasPath: ingredient.add_alias_path
      })
      return button
    }))
  }

  // Pendant JS du partial recipes/_ai_unit_badge, avec ses trois mêmes états :
  // l'unité de base suit le nom, passe en alerte quand la quantité détectée ne
  // sait pas la rejoindre, et en estimation quand elle ne l'a rejointe que par
  // une densité devinée. Mêmes classes, mêmes phrases des deux côtés.
  unitBadge(row, baseUnit, ingredient) {
    const badge = document.createElement('span')
    badge.textContent = `(${unitLabel(this.units, baseUnit)})`
    badge.className = 'ai-row__unit'

    const unit = row.dataset.aiPanelUnit
    if (this.convertQuantity(1, unit, ingredient) === null) {
      badge.classList.add('ai-row__unit--mismatch')
      badge.title = this.mismatchTitleValue
    } else if (this.usesEstimatedDensity(unit, ingredient)) {
      badge.classList.add('ai-row__unit--estimated')
      badge.title = this.estimatedTitleValue
    }

    return badge
  }

  // L'estimation telle que la voit une ligne : la même question que le badge,
  // posée sur l'unité détectée par l'IA pour cette ligne.
  estimatedFor(row, ingredient) {
    return this.usesEstimatedDensity(row?.dataset.aiPanelUnit, ingredient)
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
  quantityFor(row, ingredient) {
    const quantity = parseFloat(row.dataset.aiPanelQuantity) || 1
    const converted = this.convertQuantity(quantity, row.dataset.aiPanelUnit, ingredient)
    return converted !== null
      ? { value: converted, converted: true }
      : { value: quantity, converted: false }
  }

  // Convertit qty depuis fromUnit vers l'unité de base de l'ingrédient cible.
  // Retourne null si rien ne les relie : unités incompatibles, unité que Ruby
  // n'a pas su lire (« 2 tranches »), ou coefficient absent du catalogue.
  //
  // Miroir de UnitConversionService.convert, dans le même ordre : le facteur
  // connu d'avance, puis les deux ponts que porte l'ingrédient.
  convertQuantity(qty, fromUnit, ingredient) {
    const factor = factorTo(this.units, fromUnit, ingredient.unitGroup)
    if (factor) return round3(qty * factor)
    if (!unitDefinition(this.units, fromUnit)) return null

    return this.bridgeByPieceWeight(qty, fromUnit, ingredient) ??
           this.bridgeByDensity(qty, fromUnit, ingredient)
  }

  // Pont pièce ↔ masse par le poids unitaire : « 2 tranches » de jambon
  // deviennent 80 g si le catalogue sait qu'une tranche pèse 40 g, et rien du
  // tout s'il l'ignore.
  bridgeByPieceWeight(qty, fromUnit, { unitGroup, pieceWeight }) {
    const weight = parseFloat(pieceWeight)
    if (!(weight > 0)) return null

    if (unitGroup === 'mass') return this.through(qty, fromUnit, 'count', (pieces) => pieces * weight)
    if (unitGroup === 'count') return this.through(qty, fromUnit, 'mass', (grams) => grams / weight)
    return null
  }

  // Pont mesure ↔ masse par la densité : « 1 càs » de farine devient 8,25 g si
  // le catalogue sait qu'un millilitre en pèse 0,55.
  bridgeByDensity(qty, fromUnit, { unitGroup, density }) {
    const value = parseFloat(density)
    if (!(value > 0)) return null

    if (unitGroup === 'mass') return this.through(qty, fromUnit, 'volume', (ml) => ml * value)

    const toBase = factorTo(this.units, 'ml', unitGroup)
    return toBase ? this.through(qty, fromUnit, 'mass', (grams) => grams / value * toBase) : null
  }

  // Amène la quantité dans l'unité de base d'un groupe intermédiaire, puis laisse
  // le coefficient de l'ingrédient finir le trajet (miroir de convert_through).
  through(qty, fromUnit, pivotGroup, finish) {
    const factor = factorTo(this.units, fromUnit, pivotGroup)

    return factor ? round3(finish(qty * factor)) : null
  }

  // Miroir de UnitConversionService.estimated? : si la conversion tombe quand on
  // retire la densité, c'est elle qui l'a rendue possible — et elle n'est
  // qu'estimée, ce que le badge de la ligne doit dire.
  usesEstimatedDensity(fromUnit, ingredient) {
    if (ingredient.densitySource !== 'ai') return false
    if (this.convertQuantity(1, fromUnit, ingredient) === null) return false

    return this.convertQuantity(1, fromUnit, { ...ingredient, density: null }) === null
  }

  rowOf(element) {
    return element.closest('[data-ai-panel-target="row"]')
  }

  // Clone le template nested-form, y pose l'ingrédient et la quantité détectée,
  // et l'ajoute au formulaire.
  addPreparationRow({ id, name, baseUnit, unitGroup, row, quantityBase }) {
    const template = document.querySelector('[data-nested-form-target="template"]')
    const container = document.querySelector('[data-nested-form-target="container"]')
    if (!template || !container) return

    const timestamp = new Date().getTime()
    const html = template.innerHTML.replace(/NEW_RECORD/g, timestamp)
    const tmp = document.createElement('div')
    tmp.innerHTML = html.trim()
    const fields = tmp.firstElementChild

    const select = fields.querySelector('select[name*="ingredient_id"]')
    if (select) {
      if (!select.querySelector(`option[value="${id}"]`)) {
        const option = document.createElement('option')
        option.value = id
        option.textContent = name
        option.dataset.unit = baseUnit
        option.dataset.unitGroup = unitGroup
        select.appendChild(option)
      }
      select.value = id
    }

    // ingredient-unit lit ces deux valeurs en se connectant, c'est-à-dire à
    // l'insertion ci-dessous : c'est lui qui remplit la quantité, choisit
    // l'unité et en dérive la quantité de base soumise.
    const detected = this.detectedQuantity(row, unitGroup, baseUnit, quantityBase)
    fields.dataset.ingredientUnitQuantityValue = detected.quantity
    fields.dataset.ingredientUnitUnitValue = detected.unit

    container.appendChild(fields)
  }

  // Ce qu'on écrit dans la ligne du formulaire : de préférence la quantité telle
  // que la recette l'écrivait, dans son unité d'origine (« 3 càs d'huile »). La
  // conversion reste ainsi sous les yeux et se corrige d'un clic si l'IA s'est
  // trompée d'unité. Une unité que l'ingrédient ne sait pas saisir — « 2
  // tranches » pour un jambon au gramme — laisse place à la quantité déjà
  // convertie, dans l'unité de base.
  detectedQuantity(row, unitGroup, baseUnit, quantityBase) {
    const unit = (row?.dataset.aiPanelUnit || '').trim()
    const quantity = parseFloat(row?.dataset.aiPanelQuantity)

    // Le sélecteur de la ligne, et lui seul, décide de ce qu'on peut y écrire :
    // une unité qu'il ne contient pas laisserait la quantité s'y lire dans une
    // autre unité que celle voulue (« 20 cl de sauce soja » posés en càc).
    return unitOffered(this.units, unit, unitGroup) && quantity > 0
      ? { quantity: quantity, unit: unit }
      : { quantity: quantityBase, unit: baseUnit }
  }

  // Remplace le contenu droit de la ligne par le badge « ✓ Ajouté », nuancé des
  // deux mêmes réserves que le badge d'unité : une quantité que la conversion
  // n'a pas su traduire est posée telle quelle (à vérifier), une quantité
  // obtenue par une densité estimée n'est qu'approchée (estimée). Sans ces
  // nuances, la réserve disparaîtrait avec la ligne.
  markDone(row, { converted = true, estimated = false } = {}) {
    if (!row) return
    row.classList.add('ai-row--done')

    const search = row.querySelector('[data-ai-panel-target="search"]')
    if (search) search.hidden = true

    const rightSide = row.querySelector('.ai-row__right')
    if (!rightSide) return

    rightSide.replaceChildren(this.doneBadge(converted, estimated))
  }

  doneBadge(converted, estimated) {
    const badge = document.createElement('span')
    badge.className = 'ai-row__done-badge'

    if (!converted) {
      badge.classList.add('ai-row__done-badge--warn')
      badge.textContent = '✓ Ajouté — quantité à vérifier'
      badge.title = this.mismatchTitleValue
    } else if (estimated) {
      badge.classList.add('ai-row__done-badge--estimated')
      badge.textContent = '✓ Ajouté — quantité estimée'
      badge.title = this.estimatedTitleValue
    } else {
      badge.textContent = '✓ Ajouté'
    }

    return badge
  }
}
