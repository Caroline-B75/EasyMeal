import { Controller } from "@hotwired/stimulus"

// Autocomplétion du champ « Article » de la liste de courses.
//
// Un seul champ, deux chemins, et aucun choix à faire avant de taper : la
// frappe interroge le catalogue, et ce qu'il répond remplit ce que
// l'utilisatrice n'a alors plus à dire — le rayon, et l'unité juste pour cet
// ingrédient. S'il ne répond rien, le formulaire reste celui d'avant : un nom,
// une quantité, une unité, un rayon.
//
// Le rattachement n'est jamais qu'une commodité : le serveur retrouve seul
// l'ingrédient par son nom (Groceries::AddManualItemService), et refait de
// toute façon le travail de ce contrôleur. Une recherche qui échoue se referme
// donc en silence plutôt que d'alerter — il n'y a rien à réparer.
export default class extends Controller {
  static targets = ["nameInput", "results", "ingredientId", "unitSelect",
                    "quantityInput", "categoryGroup", "knownGroup", "chipLabel"]

  static values = {
    searchUrl: String,
    // En deçà, toute la base répondrait : « e » ne cherche rien.
    minLength: { type: Number, default: 2 },
    debounce: { type: Number, default: 200 }
  }

  connect() {
    // Les unités offertes tant qu'aucun ingrédient n'est reconnu. Mémorisées au
    // lieu d'être reconstruites : c'est le serveur qui décide de la liste (cf.
    // Units.all_select_options), le JS n'en tient pas une seconde copie.
    this.freeUnitOptions = this.unitSelectTarget.innerHTML
    this.suggestions = []
    this.activeIndex = -1
  }

  disconnect() {
    this.cancelPendingSearch()
  }

  // === Recherche ===

  search() {
    this.cancelPendingSearch()
    const query = this.nameInputTarget.value.trim()

    // Reprendre la saisie défait le rattachement : ce n'est plus le même
    // article, son rayon et ses unités ne le décrivent plus.
    if (this.attachedName && query !== this.attachedName) this.detach()

    if (query.length < this.minLengthValue) {
      this.close()
      return
    }

    this.timer = setTimeout(() => this.runSearch(query), this.debounceValue)
  }

  runSearch(query) {
    // Une frappe rapide enchaîne les requêtes : seule la dernière lancée
    // compte, les réponses arrivées dans le désordre sont ignorées.
    const requestId = (this.requestId || 0) + 1
    this.requestId = requestId

    fetch(`${this.searchUrlValue}?q=${encodeURIComponent(query)}`, { headers: { Accept: "application/json" } })
      .then((response) => response.json())
      .then((ingredients) => {
        if (requestId === this.requestId) this.render(ingredients)
      })
      .catch(() => this.close())
  }

  render(ingredients) {
    // Rien ne correspond : la liste se ferme, et le formulaire complet reste là
    // pour décrire l'article soi-même. C'est le second chemin, pas un échec.
    if (ingredients.length === 0) {
      this.close()
      return
    }

    this.suggestions = ingredients
    // append de nœuds et non innerHTML : les noms viennent de la base
    this.resultsTarget.replaceChildren(...ingredients.map((ingredient, index) => this.option(ingredient, index)))
    this.open()
  }

  option(ingredient, index) {
    const item = document.createElement("li")
    item.id = `grocery-suggestion-${index}`
    item.className = "grocery-suggestion"
    item.setAttribute("role", "option")
    item.setAttribute("aria-selected", "false")
    // mousedown et non click : il précède le blur du champ, la liste est donc
    // encore là quand le doigt se lève.
    item.dataset.action = "mousedown->ingredient-combobox#choose"
    item.dataset.index = index

    // Le libellé seul, alias compris — c'est souvent par eux qu'on a trouvé
    // l'ingrédient. Pas de rayon ici : on cherche un nom, et le rayon
    // s'affichera de toute façon une fois l'article retenu.
    item.append(ingredient.label)

    return item
  }

  // === Choix ===

  choose(event) {
    // Garde le focus dans le champ : sans cela le blur fermerait la liste avant
    // que le clic n'aboutisse.
    event.preventDefault()
    this.attach(this.suggestions[Number(event.currentTarget.dataset.index)])
  }

  // L'ingrédient reconnu remplit ce qu'on n'a plus à demander, et le curseur
  // file sur la quantité — le seul champ qui reste.
  attach(ingredient) {
    this.nameInputTarget.value = ingredient.name
    this.ingredientIdTarget.value = ingredient.id
    this.attachedName = ingredient.name

    // Les unités de CET ingrédient, la sienne présélectionnée : « 1 kg de
    // farine » reste possible, « 20 cl de curcuma » ne l'est plus.
    this.unitSelectTarget.replaceChildren(
      ...ingredient.unit_options.map(([label, unit]) => new Option(label, unit))
    )
    this.unitSelectTarget.value = ingredient.base_unit

    this.chipLabelTarget.textContent = ingredient.category_label
    this.categoryGroupTarget.hidden = true
    this.knownGroupTarget.hidden = false

    this.close()
    this.quantityInputTarget.focus()
  }

  // La croix de la puce : on reprend la main sur le rayon et l'unité, et le
  // curseur revient au nom — c'est lui qu'on s'apprête à corriger.
  unlink() {
    this.detach()
    this.nameInputTarget.focus()
  }

  // Rend la main sur le rayon et l'unité : l'article redevient une ligne libre,
  // décrite par ce qu'on en dit. Déclenché par la croix de la puce, par toute
  // reprise de la saisie, et par la remise à zéro du formulaire.
  detach() {
    this.ingredientIdTarget.value = ""
    this.attachedName = null

    // L'unité déjà choisie survit si elle figure encore parmi les unités
    // libres ; sinon le sélecteur revient à son invite (value inconnue = "").
    const chosenUnit = this.unitSelectTarget.value
    this.unitSelectTarget.innerHTML = this.freeUnitOptions
    this.unitSelectTarget.value = chosenUnit

    this.knownGroupTarget.hidden = true
    this.categoryGroupTarget.hidden = false
  }

  // === Clavier et fermeture ===

  navigate(event) {
    switch (event.key) {
      case "ArrowDown":
        event.preventDefault()
        this.moveActive(1)
        break
      case "ArrowUp":
        event.preventDefault()
        this.moveActive(-1)
        break
      case "Enter":
        // Sans proposition retenue, Entrée envoie le formulaire comme partout
        // ailleurs : le serveur retrouvera l'ingrédient par son nom.
        if (this.isOpen && this.activeIndex >= 0) {
          event.preventDefault()
          this.attach(this.suggestions[this.activeIndex])
        }
        break
      case "Escape":
        this.close()
        break
    }
  }

  moveActive(step) {
    if (!this.isOpen) return

    const options = this.optionElements
    const nextIndex = Math.min(Math.max(this.activeIndex + step, 0), options.length - 1)
    options.forEach((option, index) => option.setAttribute("aria-selected", String(index === nextIndex)))
    options[nextIndex].scrollIntoView({ block: "nearest" })

    this.activeIndex = nextIndex
    this.nameInputTarget.setAttribute("aria-activedescendant", options[nextIndex].id)
  }

  closeOnOutsideClick(event) {
    if (!this.element.contains(event.target)) this.close()
  }

  // Après un envoi réussi, le formulaire est vidé (form-reset) : l'état du
  // rattachement doit l'être aussi, sans quoi le rayon de l'article précédent
  // resterait affiché au-dessus d'un champ vide.
  reset(event) {
    if (event.detail?.success === false) return

    this.detach()
    this.close()
  }

  open() {
    this.resultsTarget.hidden = false
    this.nameInputTarget.setAttribute("aria-expanded", "true")
  }

  close() {
    this.resultsTarget.hidden = true
    this.nameInputTarget.setAttribute("aria-expanded", "false")
    this.nameInputTarget.removeAttribute("aria-activedescendant")
    this.activeIndex = -1
  }

  get isOpen() {
    return !this.resultsTarget.hidden
  }

  get optionElements() {
    return Array.from(this.resultsTarget.children)
  }

  cancelPendingSearch() {
    if (this.timer) clearTimeout(this.timer)
  }
}
