import { Controller } from "@hotwired/stimulus"
import { unitsTable, unitLabel, unitOffered, convert, usesEstimatedDensity } from "units"
import { appendPreparationRow } from "preparation_rows"
import { readSnapshot, writeSnapshot } from "form_snapshot"

// Délai avant d'interroger le catalogue, le temps que la frappe se pose
const SEARCH_DEBOUNCE_MS = 200

// Un ingrédient réduit à ce qui sert à convertir. Le JSON de la recherche parle
// en snake_case (c'est du Rails), les boutons et l'événement de création en
// camelCase : la traduction se fait ici, une fois pour toutes.
const coefficientsOf = (json) => ({
  unitGroup: json.unit_group,
  pieceWeight: json.piece_weight_g,
  pieceVolume: json.piece_volume_ml,
  density: json.density_g_per_ml,
  densitySource: json.density_source
})

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
    this.restoreDone()
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
    const { aiPanelIngredientId, aiPanelBaseUnit, aiPanelUnitGroup,
            aiPanelQuantityBase, aiPanelConverted, aiPanelEstimated } = btn.dataset

    this.addPreparationRow({ id: aiPanelIngredientId,
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

    const { id, baseUnit, unitGroup, pieceWeight, pieceVolume, density, densitySource } = event.detail
    const ingredient = { unitGroup, pieceWeight, pieceVolume, density, densitySource }

    const quantity = this.quantityFor(this.pendingRow, ingredient)
    this.addPreparationRow({ id: id, baseUnit: baseUnit, unitGroup: unitGroup,
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
    const { aiPanelIngredientId, aiPanelBaseUnit, aiPanelUnitGroup,
            aiPanelPieceWeight, aiPanelPieceVolume, aiPanelDensity, aiPanelDensitySource,
            aiPanelAddAliasPath } = btn.dataset
    const ingredient = { unitGroup: aiPanelUnitGroup, pieceWeight: aiPanelPieceWeight,
                         pieceVolume: aiPanelPieceVolume,
                         density: aiPanelDensity, densitySource: aiPanelDensitySource }

    btn.disabled = true

    this.rememberAlias(aiPanelAddAliasPath, row.dataset.aiPanelName)
      .then(() => {
        const quantity = this.quantityFor(row, ingredient)
        this.addPreparationRow({ id: aiPanelIngredientId,
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
        aiPanelBaseUnit: ingredient.base_unit,
        aiPanelUnitGroup: ingredient.unit_group,
        aiPanelPieceWeight: ingredient.piece_weight_g ?? '',
        aiPanelPieceVolume: ingredient.piece_volume_ml ?? '',
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
    if (convert(this.units, 1, unit, ingredient) === null) {
      badge.classList.add('ai-row__unit--mismatch')
      badge.title = this.mismatchTitleValue
    } else if (usesEstimatedDensity(this.units, unit, ingredient)) {
      badge.classList.add('ai-row__unit--estimated')
      badge.title = this.estimatedTitleValue
    }

    return badge
  }

  // L'estimation telle que la voit une ligne : la même question que le badge,
  // posée sur l'unité détectée par l'IA pour cette ligne.
  estimatedFor(row, ingredient) {
    return usesEstimatedDensity(this.units, row?.dataset.aiPanelUnit, ingredient)
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
    const converted = convert(this.units, quantity, row.dataset.aiPanelUnit, ingredient)
    return converted !== null
      ? { value: converted, converted: true }
      : { value: quantity, converted: false }
  }


  rowOf(element) {
    return element.closest('[data-ai-panel-target="row"]')
  }

  // Pose la ligne dans le formulaire, avec la quantité détectée. L'ingrédient
  // est forcément au catalogue — celui-ci liste tout ce que la base contient, et
  // un ingrédient créé à la volée vient d'y être inscrit (ingredient-created).
  addPreparationRow({ id, baseUnit, unitGroup, row, quantityBase }) {
    const detected = this.detectedQuantity(row, unitGroup, baseUnit, quantityBase)

    appendPreparationRow({ ingredientId: id, quantity: detected.quantity, unit: detected.unit })
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

  // Marque la ligne traitée, et retient qu'elle l'est.
  markDone(row, state) {
    this.paintDone(row, state)
    this.saveDone()
  }

  // Remplace le contenu droit de la ligne par le badge « ✓ Ajouté », nuancé des
  // deux mêmes réserves que le badge d'unité : une quantité que la conversion
  // n'a pas su traduire est posée telle quelle (à vérifier), une quantité
  // obtenue par une densité estimée n'est qu'approchée (estimée). Sans ces
  // nuances, la réserve disparaîtrait avec la ligne.
  paintDone(row, { converted = true, estimated = false } = {}) {
    if (!row) return
    row.classList.add('ai-row--done')
    // Les deux réserves restent lisibles sur la ligne : c'est d'elles que
    // l'instantané se relit, le badge lui-même n'étant que du texte.
    row.dataset.aiPanelConverted = converted
    row.dataset.aiPanelEstimated = estimated

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

  // === Mémoire des lignes déjà traitées ===
  //
  // Le panneau est rendu par le serveur, toujours neuf : un rechargement de page
  // ramenait donc toutes les lignes réclamant d'être ajoutées, alors que
  // form-recovery venait de reposer les ingrédients correspondants dans le
  // formulaire — et rien ne disait plus lesquels. Le sessionStorage retient donc,
  // le temps de l'onglet, quelles lignes ont été traitées et avec quelle réserve.
  //
  // Rien à oublier au passage : une sauvegarde acceptée ré-affiche le brouillon
  // avec ses ingrédients enregistrés, et les badges y sont tout aussi justes
  // qu'avant. Un autre import écrit ailleurs — la clé suit le formulaire.

  saveDone() {
    writeSnapshot(this.doneKey, this.rowTargets.map((row) => (
      row.classList.contains('ai-row--done')
        ? { name: row.dataset.aiPanelName,
            converted: row.dataset.aiPanelConverted === 'true',
            estimated: row.dataset.aiPanelEstimated === 'true' }
        : null
    )))
  }

  restoreDone() {
    const entries = readSnapshot(this.doneKey)
    if (!Array.isArray(entries)) return

    this.rowTargets.forEach((row, index) => {
      // Le nom détecté sert de repère : le panneau se recalcule à chaque rendu
      // (le catalogue a pu changer entre-temps), et il vaut mieux redemander une
      // ligne que d'en marquer une autre à sa place.
      const entry = entries[index]
      if (entry && entry.name === row.dataset.aiPanelName) this.paintDone(row, entry)
    })
  }

  // Une mémoire par formulaire de recette, distincte de celle de form-recovery
  // qui range la saisie du même formulaire sous la même paire méthode/action.
  get doneKey() {
    const form = this.element.closest('form')

    return `ai-panel:${form?.method}:${form?.action}`
  }
}
