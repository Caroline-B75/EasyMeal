import { Controller } from "@hotwired/stimulus"

// Choix d'un ingrédient dans une ligne du formulaire de recette.
//
// Le sélecteur natif ne cherchait qu'au début des libellés : taper « poulet »
// tombait sur « Poulet entier », et « Blanc de poulet » restait introuvable
// autrement qu'en parcourant les quelque 600 entrées du catalogue. Ce
// contrôleur pose devant lui un champ de saisie et une liste filtrée, où
// « poulet » trouve aussi bien l'un que l'autre.
//
// Le <select> reste le champ soumis et la seule source de vérité : c'est de ses
// options que la liste est filtrée — donc du catalogue déjà rendu dans la page,
// sans requête ni attente —, et c'est lui qu'un choix met à jour, suivi du
// `change` qui fait relire l'ingrédient à `ingredient-unit`. Tout ce qui écrit
// déjà dans ce sélecteur continue ainsi de fonctionner sans rien savoir d'ici —
// le panneau d'import IA, la création d'un ingrédient à la volée, la
// restauration d'une saisie —, et le `change` que ces contrôleurs émettent
// ramène le libellé affiché en accord avec la sélection (cf. showSelection).
//
// Sans JavaScript, rien de tout cela n'existe : le rendu serveur montre le
// sélecteur natif et cache le champ de recherche. C'est la connexion qui
// échange les deux, et le formulaire s'utilise sinon comme avant.

// Comparaison à la casse, aux accents et aux ligatures près — le pendant JS de
// l'`unaccent` de Postgres, qui sert la même recherche côté serveur :
// « epinard » trouve « Épinards », « boeuf » trouve « Bœuf haché ».
const normalize = (text) =>
  text
    .toLowerCase()
    .normalize("NFD")
    .replace(/\p{Diacritic}/gu, "")
    .replace(/œ/g, "oe")
    .replace(/æ/g, "ae")

// Rang d'une proposition, pour que le nom qui commence par ce qu'on tape passe
// devant celui qui le porte plus loin : « poulet » garde « Poulet entier » en
// tête, puis vient « Blanc de poulet » — dont un mot commence par le terme —,
// puis le reste. Le terme est toujours présent dans le libellé : seules les
// propositions retenues par le filtre sont classées.
const rank = (label, term) => {
  const at = label.indexOf(term)
  if (at === 0) return 0

  return /\W/.test(label[at - 1]) ? 1 : 2
}

export default class extends Controller {
  static targets = ["input", "results", "select"]

  connect() {
    this.selectTarget.hidden = true
    this.inputTarget.hidden = false
    this.activeIndex = -1
    this.showSelection()
  }

  // === Recherche ===

  // Le champ reprend le geste du sélecteur qu'il remplace : au focus, tout le
  // catalogue s'ouvre. Le libellé déjà là est sélectionné, pour que la première
  // frappe le remplace au lieu de s'y insérer.
  open() {
    this.inputTarget.select()
    this.query = ""
    this.render()
  }

  // Un clic rouvre la liste refermée par un choix : le champ n'avait pas perdu
  // le focus, l'événement `focus` ne se reproduit donc pas. Liste déjà ouverte,
  // en revanche, le clic ne fait rien — c'est ainsi qu'on place le curseur dans
  // le texte sans que tout soit resélectionné.
  reopen() {
    if (!this.isOpen) this.open()
  }

  search() {
    this.query = this.inputTarget.value
    this.render()
  }

  // Les ingrédients dont le libellé porte tous les mots tapés, dans n'importe
  // quel ordre : « blanc poulet » trouve « Blanc de poulet ». Les alias
  // comptent, eux aussi — ils sont écrits dans le libellé des options
  // (Ingredient#select_label), et c'est souvent par eux qu'on cherche.
  //
  // Rien n'est plafonné, et c'est délibéré : la liste défile (max-height), une
  // recherche ne doit donc pas taire de correspondance, et sans recherche c'est
  // tout le catalogue qui s'ouvre — le sélecteur natif se parcourait ainsi, on
  // ne le remplace pas en lui retirant ce geste.
  matches() {
    const terms = normalize(this.query).split(/\s+/).filter(Boolean)
    if (terms.length === 0) return this.options

    return this.options
      .map((option) => ({ option, label: normalize(option.text) }))
      .filter(({ label }) => terms.every((term) => label.includes(term)))
      // Tri stable : à rang égal, l'ordre alphabétique du catalogue est conservé.
      .sort((a, b) => rank(a.label, terms[0]) - rank(b.label, terms[0]))
      .map(({ option }) => option)
  }

  // Les options du sélecteur, son invite mise à part. Relues à chaque frappe et
  // jamais mémorisées : la liste se complète après le rendu — `ingredient-options`
  // y verse le catalogue sur les lignes déjà remplies, la création d'un
  // ingrédient à la volée y insère une entrée.
  get options() {
    return Array.from(this.selectTarget.options).filter((option) => option.value)
  }

  // === Liste ===

  render() {
    const matches = this.matches()

    // Aucune correspondance : la liste se ferme plutôt que d'afficher un vide.
    // Ce qui reste tapé n'engage rien — le sélecteur garde sa valeur.
    if (matches.length === 0) {
      this.close()
      return
    }

    // append de nœuds et non innerHTML : les libellés viennent de la base.
    this.resultsTarget.replaceChildren(...matches.map((option, index) => this.item(option, index)))
    this.resultsTarget.hidden = false
    this.inputTarget.setAttribute("aria-expanded", "true")

    // Une recherche désigne d'emblée sa meilleure proposition : Entrée la
    // retient sans avoir à descendre dessus. Le catalogue ouvert sans recherche,
    // lui, ne présume de rien.
    this.activate(this.query ? 0 : -1)
  }

  item(option, index) {
    const item = document.createElement("li")
    item.id = `${this.resultsTarget.id}-${index}`
    item.className = "ingredient-picker__option"
    item.setAttribute("role", "option")
    item.setAttribute("aria-selected", "false")
    // mousedown et non click : il précède le blur du champ, la liste est donc
    // encore là quand le doigt se lève.
    item.dataset.action = "mousedown->ingredient-picker#choose"
    item.dataset.value = option.value
    item.append(option.text)

    return item
  }

  // === Choix ===

  choose(event) {
    // Garde le focus dans le champ : sans cela le blur fermerait la liste avant
    // que le clic n'aboutisse.
    event.preventDefault()
    this.commit(event.currentTarget.dataset.value)
  }

  // Retient un ingrédient. Le sélecteur est le champ soumis, c'est donc lui
  // qu'on met à jour ; le `change` qui suit fait relire l'ingrédient à
  // `ingredient-unit`, qui aligne les unités saisissables, et revient ici poser
  // le libellé dans le champ.
  commit(value) {
    this.selectTarget.value = value
    this.selectTarget.dispatchEvent(new Event("change", { bubbles: true }))
    this.close()
  }

  // Ce que le champ montre : le libellé de l'ingrédient retenu, ou rien. Appelé
  // à la connexion et à chaque `change` du sélecteur — y compris ceux qu'émettent
  // les autres contrôleurs quand ils y posent un ingrédient.
  showSelection() {
    this.inputTarget.value = this.selectedOption?.text || ""
    this.query = ""
  }

  // L'option retenue, l'invite « Choisir un ingrédient... » exclue : elle porte
  // la valeur vide, et ne nomme aucun ingrédient.
  get selectedOption() {
    const option = this.selectTarget.selectedOptions[0]

    return option?.value ? option : null
  }

  // === Clavier et fermeture ===

  navigate(event) {
    switch (event.key) {
      case "ArrowDown":
        event.preventDefault()
        if (this.isOpen) this.move(1)
        else this.open()
        break
      case "ArrowUp":
        event.preventDefault()
        this.move(-1)
        break
      case "Enter":
        // Liste fermée : la touche revient au formulaire, comme partout ailleurs.
        if (!this.isOpen) break
        event.preventDefault()
        if (this.activeIndex >= 0) this.commit(this.items[this.activeIndex].dataset.value)
        break
      case "Escape":
      case "Tab":
        // La recherche est abandonnée, ou le champ quitté : ce qui a été tapé
        // sans être choisi ne vaut rien, le champ doit redire ce qui sera soumis.
        this.close()
        this.showSelection()
        break
    }
  }

  move(step) {
    if (!this.isOpen) return

    const items = this.items
    const next = Math.min(Math.max(this.activeIndex + step, 0), items.length - 1)

    this.activate(next)
    items[next].scrollIntoView({ block: "nearest" })
  }

  activate(index) {
    this.activeIndex = index
    this.items.forEach((item, position) => item.setAttribute("aria-selected", String(position === index)))

    if (index < 0) this.inputTarget.removeAttribute("aria-activedescendant")
    else this.inputTarget.setAttribute("aria-activedescendant", this.items[index].id)
  }

  // Un clic ailleurs dans la page ferme la liste, et le champ redit l'ingrédient
  // retenu. Un clic dans la liste elle-même n'est pas « ailleurs » : c'est ce
  // qui permet d'en faire glisser la barre de défilement sans tout refermer.
  closeOnOutsideClick(event) {
    if (this.element.contains(event.target)) return

    this.close()
    this.showSelection()
  }

  close() {
    this.resultsTarget.hidden = true
    // Vidée et non seulement masquée : sans recherche, la liste porte le
    // catalogue entier, et une dizaine de lignes d'ingrédient laisseraient
    // autant de milliers de nœuds derrière elles. Seule la liste ouverte en
    // garde, et `render` la reconstruit à la réouverture.
    this.resultsTarget.replaceChildren()
    this.inputTarget.setAttribute("aria-expanded", "false")
    this.inputTarget.removeAttribute("aria-activedescendant")
    this.activeIndex = -1
  }

  get isOpen() {
    return !this.resultsTarget.hidden
  }

  get items() {
    return Array.from(this.resultsTarget.children)
  }
}
