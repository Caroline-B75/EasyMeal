import { Controller } from "@hotwired/stimulus"

// Rend un groupe de boutons radio « décochable » : recliquer sur l'option déjà
// active la retire et remet le champ à vide.
//
// Les sélecteurs segmentés des champs facultatifs (difficulté, budget)
// n'affichent pas d'option « Non renseigné » — sans ce comportement, une valeur
// posée par erreur ne pourrait plus jamais être retirée.
export default class extends Controller {
  // Mémorise l'option cochée AVANT le clic en cours. Indispensable de le faire
  // en amont (mousedown / keydown) : au moment du clic, le navigateur a déjà
  // coché l'option visée, et « nouvelle option » ne se distingue plus de
  // « option déjà active ».
  remember() {
    this.previouslyChecked = this.checkedRadio
  }

  // Branché sur le radio lui-même : le clic sur le label est relayé par le
  // navigateur au radio, donc l'action ne se déclenche qu'une fois par clic.
  toggle(event) {
    const radio = event.currentTarget
    if (radio !== this.previouslyChecked) return

    radio.checked = false
    this.previouslyChecked = null
  }

  get checkedRadio() {
    return this.element.querySelector("input[type='radio']:checked")
  }
}
