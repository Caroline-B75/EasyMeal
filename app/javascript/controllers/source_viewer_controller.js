import { Controller } from "@hotwired/stimulus"

// Visionneuse de la page photographiée à l'import, posée à côté du formulaire de
// validation. Une image tenue dans une colonne de 400 px ne se lit pas : ce
// contrôleur lui donne les gestes d'une carte — molette pour zoomer sous le
// curseur, glisser pour se déplacer, double-clic pour aller-retour — et gère son
// repli, y compris le repli forcé des écrans trop étroits pour deux colonnes, où
// la visionneuse repasse en superposition.
//
// L'échelle et la translation vivent ici et n'atteignent le DOM que par une seule
// écriture (render) : c'est la transformation CSS de l'image, jamais sa taille,
// qui bouge.

// Bornes du zoom. 1 = l'image ajustée à son cadre (object-fit: contain) ; au-delà
// de 5, un import de 1600 px n'a plus de détail à montrer.
const MIN_SCALE = 1
const MAX_SCALE = 5

// Un cran de molette, et le palier du double-clic : assez franc pour lire une
// quantité écrite en petit d'un seul geste.
const ZOOM_STEP = 1.25
const DOUBLE_CLICK_SCALE = 2.5

// Largeur en dessous de laquelle formulaire et visionneuse ne tiennent plus côte
// à côte (miroir du point de bascule CSS, cf. recipes.css « Visionneuse »).
const WIDE_SCREEN = "(min-width: 1200px)"

// Préférence de repli, retenue d'un import au suivant : on valide souvent
// plusieurs brouillons d'affilée avec la même façon de travailler.
const STORAGE_KEY = "easymeal.sourceViewer"
const CLOSED = "closed"
const OPEN = "open"

// Les deux états par défaut appartiennent au CSS (colonne ouverte sur grand
// écran, languette seule en dessous) : ces classes ne marquent que l'écart au
// défaut de la largeur courante.
const OPENED_CLASS = "is-source-open"
const HIDDEN_CLASS = "is-source-hidden"

export default class extends Controller {
  static targets = ["frame", "image", "level"]

  connect() {
    this.adjustToScreen()
  }

  // === Repli / dépli ===

  open() {
    this.element.classList.remove(HIDDEN_CLASS)
    this.element.classList.add(OPENED_CLASS)
    this.remember(OPEN)
  }

  close() {
    this.element.classList.remove(OPENED_CLASS)
    this.element.classList.add(HIDDEN_CLASS)
    this.remember(CLOSED)
    // Rouvrir sur un fragment d'image agrandi au hasard désorienterait : la
    // visionneuse repart toujours de la page entière.
    this.reset()
  }

  // Franchir le seuil des deux colonnes rend la visionneuse à l'état que le CSS
  // prévoit pour cette largeur — sinon une fenêtre réduite garderait ouverte, en
  // superposition, une colonne qu'on avait simplement laissée visible. C'est
  // aussi l'initialisation : ne rien poser au chargement, c'est ne rien faire
  // clignoter le temps que Stimulus s'attache.
  adjustToScreen() {
    if (this.wasWide === this.wide) return

    this.wasWide = this.wide
    this.element.classList.remove(OPENED_CLASS, HIDDEN_CLASS)
    this.reset()

    // Seul écart à rétablir : un repli déjà choisi sur grand écran.
    if (this.wide && this.stored === CLOSED) this.close()
  }

  // Écran étroit : le voile de la superposition est l'aside elle-même, seul un
  // clic à côté de la plaque blanche la referme.
  closeOnOverlay(event) {
    if (this.wide || event.target !== event.currentTarget) return

    this.close()
  }

  // Échap ne ferme que la superposition : sur grand écran, la colonne n'est pas
  // un panneau modal et rien n'attend d'être « échappé ».
  closeOnEscape(event) {
    if (event.key !== "Escape" || this.wide) return

    this.close()
  }

  // === Zoom ===

  zoomIn() {
    this.zoomTo(this.scale * ZOOM_STEP)
  }

  zoomOut() {
    this.zoomTo(this.scale / ZOOM_STEP)
  }

  reset() {
    this.scale = MIN_SCALE
    this.x = 0
    this.y = 0
    this.render()
  }

  // La molette zoome au lieu de faire défiler la page : dans un visualiseur
  // d'image, c'est le geste attendu — et la colonne n'a rien à faire défiler.
  wheelZoom(event) {
    event.preventDefault()

    const factor = event.deltaY < 0 ? ZOOM_STEP : 1 / ZOOM_STEP
    this.zoomTo(this.scale * factor, this.pointerOffset(event))
  }

  // Double-clic : agrandit l'endroit visé, ou revient à la page entière si on y
  // est déjà — un aller-retour, sans passer par les boutons.
  toggleZoom(event) {
    if (this.scale > MIN_SCALE) return this.reset()

    this.zoomTo(DOUBLE_CLICK_SCALE, this.pointerOffset(event))
  }

  // Change l'échelle en gardant sous le curseur le point qu'il désignait :
  // t' = m + (t − m) × (s'/s), où m est ce point dans le repère du cadre.
  // Sans cette correction, zoomer sur un ingrédient l'éloignerait du curseur.
  zoomTo(scale, origin = { x: 0, y: 0 }) {
    const next = Math.min(MAX_SCALE, Math.max(MIN_SCALE, scale))
    const factor = next / this.scale

    this.x = origin.x + (this.x - origin.x) * factor
    this.y = origin.y + (this.y - origin.y) * factor
    this.scale = next
    this.render()
  }

  // === Déplacement ===

  // Pas de preventDefault ici, contrairement au réflexe : sur pointerdown il
  // supprime les événements souris de compatibilité, donc le dblclick qui remet
  // la page entière. Le glisser natif de l'image est écarté autrement — attribut
  // draggable et user-select dans la vue et la feuille de style.
  startPan(event) {
    // À l'échelle 1 l'image tient entière dans son cadre : rien à déplacer.
    if (this.scale === MIN_SCALE) return

    this.panPointerId = event.pointerId
    this.panOrigin = { x: event.clientX - this.x, y: event.clientY - this.y }
    // Capture du pointeur : le déplacement se poursuit même si le curseur sort
    // du cadre, et le relâchement nous revient toujours.
    this.frameTarget.setPointerCapture(event.pointerId)
    this.frameTarget.classList.add("is-panning")
  }

  pan(event) {
    if (this.panPointerId !== event.pointerId) return

    this.x = event.clientX - this.panOrigin.x
    this.y = event.clientY - this.panOrigin.y
    this.render()
  }

  endPan(event) {
    if (this.panPointerId !== event.pointerId) return

    this.panPointerId = null
    this.frameTarget.classList.remove("is-panning")
  }

  // === Rendu ===

  render() {
    this.clampOffsets()

    this.imageTarget.style.transform = `translate(${this.x}px, ${this.y}px) scale(${this.scale})`
    // Espace insécable avant le signe %, comme le veut la typographie française.
    this.levelTarget.textContent = `${Math.round(this.scale * 100)} %`
    // Porte le curseur (loupe ou main) et l'état du bouton de réinitialisation.
    this.frameTarget.classList.toggle("is-zoomed", this.scale > MIN_SCALE)
  }

  // Retient l'image dans son cadre : au-delà, on ferait glisser du vide.
  clampOffsets() {
    const { width, height, frame } = this.fittedSize
    const maxX = Math.max(0, (width * this.scale - frame.width) / 2)
    const maxY = Math.max(0, (height * this.scale - frame.height) / 2)

    this.x = Math.min(maxX, Math.max(-maxX, this.x))
    this.y = Math.min(maxY, Math.max(-maxY, this.y))
  }

  // Place réellement occupée par l'image à l'échelle 1, que object-fit: contain
  // déduit du rapport le plus contraignant. Avant le chargement de l'image ses
  // dimensions naturelles valent 0 : le cadre fait alors office de mesure, ce qui
  // annule simplement le déplacement (rien n'est encore visible à déplacer).
  get fittedSize() {
    const frame = this.frameTarget.getBoundingClientRect()
    const { naturalWidth, naturalHeight } = this.imageTarget
    if (!naturalWidth || !naturalHeight) return { width: frame.width, height: frame.height, frame }

    const ratio = Math.min(frame.width / naturalWidth, frame.height / naturalHeight)
    return { width: naturalWidth * ratio, height: naturalHeight * ratio, frame }
  }

  // Position du curseur rapportée au centre du cadre — le repère dans lequel
  // s'exprime la translation appliquée à l'image.
  pointerOffset(event) {
    const frame = this.frameTarget.getBoundingClientRect()

    return {
      x: event.clientX - (frame.left + frame.width / 2),
      y: event.clientY - (frame.top + frame.height / 2)
    }
  }

  // === Préférence de repli ===

  get wide() {
    return window.matchMedia(WIDE_SCREEN).matches
  }

  // localStorage peut être refusé (navigation privée verrouillée) : la préférence
  // est un confort, son indisponibilité ne doit pas emporter la visionneuse.
  get stored() {
    try {
      return window.localStorage.getItem(STORAGE_KEY)
    } catch {
      return null
    }
  }

  remember(state) {
    // Sur écran étroit, le repli est imposé par la place et non choisi : il n'a
    // rien à dire de la façon de travailler sur grand écran.
    if (!this.wide) return

    try {
      window.localStorage.setItem(STORAGE_KEY, state)
    } catch {
      // Préférence perdue, sans conséquence sur la visionneuse elle-même.
    }
  }
}
