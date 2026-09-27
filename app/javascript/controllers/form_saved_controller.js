import { Controller } from "@hotwired/stimulus"
import { forgetInFlight } from "form_snapshot"

// Posé par le layout sur la page qui suit une sauvegarde acceptée : la saisie
// du formulaire soumis est en base, son instantané n'a plus rien à reposer.
// Sans lui, le formulaire suivant à la même adresse — une nouvelle recette
// après la précédente — se remplissait de la recette tout juste créée.
export default class extends Controller {
  connect() {
    forgetInFlight()
  }
}
