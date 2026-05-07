// Soumet automatiquement un formulaire lors d'un changement de valeur.
// Usage : data-controller="auto-submit" sur le <form>,
//         data-action="change->auto-submit#submit" sur le <select>/<input>.
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  submit() {
    this.element.requestSubmit()
  }
}
