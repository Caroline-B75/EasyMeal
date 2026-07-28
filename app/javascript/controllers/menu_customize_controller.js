// Contrôleur Stimulus pour la page de personnalisation du menu (card grid).
// Gère : drag & drop visuel, compteur de repas, publication de la hauteur de carte.
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["grid", "card", "countChip"]
  static values  = { reorderUrl: String }

  connect() {
    this.dragSrc = null
    this.syncCardHeight()
    this.updateCount()
    this.observeGrid()
    window.addEventListener("resize", this.boundResize = () => this.syncCardHeight())
  }

  disconnect() {
    this.gridObserver?.disconnect()
    window.removeEventListener("resize", this.boundResize)
  }

  // ── Observation du grid pour MAJ automatique du compteur ──
  observeGrid() {
    if (!this.hasGridTarget) return
    this.gridObserver = new MutationObserver(() => {
      this.updateCount()
      this.syncCardHeight()
    })
    this.gridObserver.observe(this.gridTarget, { childList: true })
  }

  // ── Compteur de repas (chip dans la context bar) ────────
  updateCount() {
    const n = this.hasGridTarget
      ? this.gridTarget.querySelectorAll(".mc-recipe-card").length
      : 0
    if (this.hasCountChipTarget) {
      this.countChipTarget.textContent = `${n} repas`
    }
  }

  // ── Hauteur d'une carte de recette ──────────────────────
  // La hauteur d'une carte dépend de la largeur de colonne du grid (photo
  // carrée) : elle n'est pas calculable en CSS. On la mesure ici et on la
  // publie en variable CSS sur l'élément de page, que les blocs qui doivent
  // s'aligner sur une carte consomment en CSS (slot d'ajout, panneau de
  // réglages). Pas de style inline : la valeur survit au remplacement de ces
  // blocs par un Turbo Stream (stepper « nombre de personnes »).
  syncCardHeight() {
    if (!this.hasGridTarget) return
    const firstCard = this.gridTarget.querySelector(".mc-recipe-card")
    const cardH = firstCard ? firstCard.getBoundingClientRect().height : 0

    // Grille vide (ou pas encore mise en page) : pas de référence, on retire la
    // variable plutôt que de laisser une hauteur périmée.
    if (cardH < 10) {
      this.element.style.removeProperty("--mc-card-height")
      return
    }
    this.element.style.setProperty("--mc-card-height", `${Math.round(cardH)}px`)
  }

  // ── Drag & Drop (réordonnement visuel) ──────────────────
  dragStart(event) {
    this.dragSrc = event.currentTarget
    event.dataTransfer.effectAllowed = "move"
    // Délai pour que la classe dragging ne bloque pas le drag
    setTimeout(() => event.currentTarget.classList.add("mc-dragging"), 0)
  }

  dragEnd(event) {
    event.currentTarget.classList.remove("mc-dragging")
    this.gridTarget.querySelectorAll(".mc-drag-over").forEach(el =>
      el.classList.remove("mc-drag-over")
    )
    this.dragSrc = null
  }

  dragOver(event) {
    event.preventDefault()
    const card = event.currentTarget
    if (this.dragSrc && this.dragSrc !== card) {
      card.classList.add("mc-drag-over")
    }
  }

  dragLeave(event) {
    event.currentTarget.classList.remove("mc-drag-over")
  }

  drop(event) {
    event.preventDefault()
    const target = event.currentTarget
    target.classList.remove("mc-drag-over")
    if (!this.dragSrc || this.dragSrc === target) return

    const grid = this.gridTarget
    const srcWrapper = this._gridChild(this.dragSrc)
    const tgtWrapper = this._gridChild(target)
    if (!srcWrapper || !tgtWrapper) return

    const children = [...grid.children]
    const srcIdx = children.indexOf(srcWrapper)
    const tgtIdx = children.indexOf(tgtWrapper)
    grid.insertBefore(srcWrapper, srcIdx < tgtIdx ? tgtWrapper.nextSibling : tgtWrapper)
    this.persistOrder()
  }

  // Remonte jusqu'au fils direct du grid (turbo-frame ou l'élément lui-même)
  _gridChild(el) {
    while (el && el.parentElement !== this.gridTarget) {
      el = el.parentElement
    }
    return el
  }

  // ── Persistance de l'ordre après drag & drop ────────────
  persistOrder() {
    if (!this.hasReorderUrlValue) return
    const ids = [...this.gridTarget.querySelectorAll("turbo-frame[id^='menu_recipe_']")]
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
