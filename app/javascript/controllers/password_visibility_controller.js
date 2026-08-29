import { Controller } from "@hotwired/stimulus"

// Œil d'affichage d'un champ de mot de passe.
//
// Deux gestes, dont un seul est évident : basculer le type du champ entre
// `password` et `text`. L'autre est la mise en place — le bouton doit se poser
// contre le champ, or simple_form enveloppe celui-ci entre un libellé et une
// aide dont les hauteurs varient. Un positionnement en CSS depuis le groupe
// devrait donc deviner la hauteur du libellé ; on préfère glisser un conteneur
// autour du seul champ, et y ancrer le bouton.
export default class extends Controller {
  static targets = ["input", "button"]

  connect() {
    this.wrap()
  }

  // Bascule l'affichage. Le focus revient au champ, à la position où il était :
  // changer le `type` d'un input replace le curseur à la fin, ce qui ferait
  // repartir la frappe au mauvais endroit quand on vérifie en cours de saisie.
  toggle() {
    const visible = this.inputTarget.type === "text"
    const { selectionStart, selectionEnd } = this.inputTarget

    this.inputTarget.type = visible ? "password" : "text"
    this.element.classList.toggle("password-field--visible", !visible)
    this.buttonTarget.setAttribute("aria-pressed", String(!visible))
    this.buttonTarget.setAttribute("aria-label", visible ? "Afficher le mot de passe" : "Masquer le mot de passe")

    this.inputTarget.focus()
    // Un champ `password` refuse setSelectionRange sur certains navigateurs :
    // on ne restaure la position que là où elle a un sens.
    if (selectionStart !== null) this.inputTarget.setSelectionRange(selectionStart, selectionEnd)
  }

  // Glisse un conteneur autour du champ et y déplace le bouton, qui était rendu
  // à la fin du groupe. Idempotent : une reconnexion (Turbo, morphing) ne doit
  // pas empiler les conteneurs.
  wrap() {
    if (this.element.querySelector(".password-field__control")) return

    const control = document.createElement("div")
    control.className = "password-field__control"

    this.inputTarget.parentNode.insertBefore(control, this.inputTarget)
    control.append(this.inputTarget, this.buttonTarget)
  }
}
