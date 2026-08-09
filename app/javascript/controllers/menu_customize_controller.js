// Contrôleur Stimulus des pages de menu en grille — brouillon ET menu actif :
// sur un menu validé, le jour et l'ordre des cartes restent à la main de
// l'utilisatrice. Les repas vivent dans une grille unique dont l'ordre lui
// appartient (UC7). Gère : drag & drop, teinte de jour, compteur de repas
// (brouillon seulement, seul état où le nombre de cartes bouge), publication
// de la hauteur de carte.
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["grid", "countChip"]
  static values  = { reorderUrl: String }

  connect() {
    this.dragSrc = null
    this.refreshFrame = null
    this.syncCardHeight()
    this.updateCount()
    this.observeCards()
    window.addEventListener("resize", this.boundResize = () => this.syncCardHeight())
  }

  disconnect() {
    this.cardsObserver?.disconnect()
    if (this.refreshFrame) cancelAnimationFrame(this.refreshFrame)
    window.removeEventListener("resize", this.boundResize)
  }

  // ── Observation des cartes pour MAJ automatique du compteur ──
  // Posé sur l'élément racine (subtree) et non sur la grille : le Turbo Stream
  // de suppression remplace le bloc des repas entier, un observer accroché à la
  // grille mourrait avec elle.
  observeCards() {
    this.cardsObserver = new MutationObserver(() => this.scheduleRefresh())
    this.cardsObserver.observe(this.element, { childList: true, subtree: true })
  }

  // Les mutations arrivent en rafale — un Turbo Stream remplace le bloc des
  // repas d'un seul tenant : on ne recalcule qu'une fois par frame, sinon
  // syncCardHeight force autant de reflows qu'il y a de nœuds touchés.
  scheduleRefresh() {
    if (this.refreshFrame) return
    this.refreshFrame = requestAnimationFrame(() => {
      this.refreshFrame = null
      this.updateCount()
      this.syncCardHeight()
    })
  }

  // ── Compteur de repas (chip dans l'en-tête) ─────────────
  // Le chip vit dans l'en-tête, donc DANS le sous-arbre observé ci-dessus, et
  // affecter textContent recrée le nœud texte — c'est une mutation childList
  // même à texte identique. Sans cette écriture conditionnelle, l'observer se
  // rappellerait lui-même sans fin et figerait l'onglet.
  updateCount() {
    if (!this.hasCountChipTarget) return

    const label = `${this.element.querySelectorAll(".mc-recipe-card").length} repas`
    if (this.countChipTarget.textContent !== label) {
      this.countChipTarget.textContent = label
    }
  }

  // ── Hauteur d'une carte de recette ──────────────────────
  // La hauteur d'une carte dépend de la largeur de colonne du grid (photo
  // carrée) : elle n'est pas calculable en CSS. On la mesure ici et on la
  // publie en variable CSS sur l'élément de page, que les blocs qui doivent
  // s'aligner sur une carte consomment en CSS (bouton « + catalogue »,
  // panneau de réglages). Pas de style inline : la valeur survit au
  // remplacement de ces blocs par un Turbo Stream.
  syncCardHeight() {
    const firstCard = this.element.querySelector(".mc-recipe-card")
    const cardH = firstCard ? firstCard.getBoundingClientRect().height : 0

    // Page sans carte (ou pas encore mise en page) : pas de référence, on
    // retire la variable plutôt que de laisser une hauteur périmée.
    if (cardH < 10) {
      this.element.style.removeProperty("--mc-card-height")
      return
    }
    this.element.style.setProperty("--mc-card-height", `${Math.round(cardH)}px`)
  }

  // ── Teinte de jour ──────────────────────────────────────
  // Posée tout de suite sur la carte, sans attendre le serveur : le <select>
  // qui déclenche le changement vit DANS la carte, la re-rendre lui ferait
  // perdre le focus. Le serveur ne fait plus que persister (204).
  setDay(event) {
    const card = event.target.closest(".mc-recipe-card")
    if (!card) return

    if (event.target.value === "") {
      delete card.dataset.day
    } else {
      card.dataset.day = event.target.value
    }
  }

  // ── Drag & Drop (réordonnement de la grille) ────────────
  // Aucune frontière : l'ordre des repas appartient à l'utilisatrice, qui
  // range sa semaine comme elle la vit (UC7).
  dragStart(event) {
    const card = event.currentTarget
    this.dragSrc = card
    event.dataTransfer.effectAllowed = "move"
    // Délai pour que la classe dragging ne bloque pas le drag. On capture la
    // carte ci-dessus : event.currentTarget est remis à null à la fin de la
    // propagation, il ne vaut plus rien dans un callback différé.
    setTimeout(() => card.classList.add("mc-dragging"), 0)
  }

  // Balayage plutôt que nettoyage de la seule carte source : un Turbo Stream
  // peut avoir remplacé les cartes pendant le glissement, laissant une classe
  // orpheline sur un nœud qui n'est plus celui qu'on a saisi.
  dragEnd() {
    this.element.querySelectorAll(".mc-dragging, .mc-drag-over").forEach(el =>
      el.classList.remove("mc-dragging", "mc-drag-over")
    )
    this.dragSrc = null
  }

  dragOver(event) {
    const card = event.currentTarget
    if (!this.dragSrc || this.dragSrc === card) return

    event.preventDefault()
    card.classList.add("mc-drag-over")
  }

  dragLeave(event) {
    event.currentTarget.classList.remove("mc-drag-over")
  }

  drop(event) {
    event.preventDefault()
    const target = event.currentTarget
    target.classList.remove("mc-drag-over")
    if (!this.dragSrc || this.dragSrc === target || !this.hasGridTarget) return

    const grid = this.gridTarget
    const srcWrapper = this._gridChild(this.dragSrc, grid)
    const tgtWrapper = this._gridChild(target, grid)
    if (!srcWrapper || !tgtWrapper) return

    const children = [...grid.children]
    const srcIdx = children.indexOf(srcWrapper)
    const tgtIdx = children.indexOf(tgtWrapper)
    grid.insertBefore(srcWrapper, srcIdx < tgtIdx ? tgtWrapper.nextSibling : tgtWrapper)
    this.persistOrder()
  }

  // Remonte jusqu'au fils direct de la grille (turbo-frame ou l'élément lui-même).
  // null si l'élément n'est pas dans la grille — le bouton « + » l'est aussi,
  // mais il n'est pas draggable, il n'arrive donc jamais ici.
  _gridChild(el, grid) {
    while (el && el.parentElement !== grid) {
      el = el.parentElement
    }
    return el
  }

  // ── Persistance de l'ordre après drag & drop ────────────
  // L'ordre envoyé est celui du DOM : la position est une séquence unique sur
  // tout le menu, le moment de chaque repas (meal_type) en étant indépendant.
  persistOrder() {
    if (!this.hasReorderUrlValue) return
    const ids = [...this.element.querySelectorAll("turbo-frame[id^='menu_recipe_']")]
      .map(f => f.id.replace("menu_recipe_", ""))
      .filter(id => /^\d+$/.test(id))

    const csrfToken = document.querySelector('meta[name="csrf-token"]')?.content
    fetch(this.reorderUrlValue, {
      method: "PATCH",
      headers: {
        "Content-Type": "application/json",
        "X-CSRF-Token": csrfToken
      },
      body: JSON.stringify({ ids })
    })
  }
}
