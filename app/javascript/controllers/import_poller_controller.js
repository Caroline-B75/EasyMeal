import { Controller } from "@hotwired/stimulus"

// Page d'attente d'un import IA.
//
// Le travail se fait dans un job, hors de la requête : cette page revient donc
// régulièrement demander où il en est. Le serveur répond soit la même page
// d'attente — avec son étape remise à jour, calculée à partir du temps écoulé —,
// soit une redirection vers le formulaire de validation, que Turbo suit tout
// seul. Rien à décider ici : la page se contente de revenir voir.
//
// On remplace l'entrée d'historique plutôt que d'en empiler une : le bouton
// Retour ne doit pas ramener dans une attente déjà terminée.
export default class extends Controller {
  static values = { interval: { type: Number, default: 2000 } }

  connect() {
    this.timer = setInterval(() => this.check(), this.intervalValue)
  }

  disconnect() {
    clearInterval(this.timer)
  }

  check() {
    window.Turbo.visit(window.location.href, { action: "replace" })
  }
}
