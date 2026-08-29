import { Controller } from "@hotwired/stimulus"
import { catalogOptions } from "preparation_rows"

// Complète un sélecteur d'ingrédient avec le catalogue entier.
//
// Le catalogue approche les 600 entrées : le répéter dans chaque ligne du
// formulaire pesait 58 Ko par ligne, et une recette d'une dizaine
// d'ingrédients servait un demi-méga de HTML dont 90 % en doublons. Il n'est
// donc rendu qu'une fois, dans le modèle de ligne du nested-form ; les lignes
// déjà remplies n'affichent que leur ingrédient et empruntent le reste ici.
//
// Le modèle de ligne, lui, garde sa liste complète : c'est de lui que
// `nested-form` et le panneau d'import IA clonent les nouvelles lignes, qui
// arrivent ainsi déjà garnies — ce contrôleur ne les concerne pas.
export default class extends Controller {
  connect() {
    const options = catalogOptions()
    if (options.length === 0) return

    // La sélection courante est portée par une option rendue par le serveur,
    // que le catalogue va remplacer : on la relit avant, on la repose après.
    const selected = this.element.value

    this.element.append(...options.map((option) => option.cloneNode(true)))
    this.dedupe(selected)
    this.element.value = selected
  }

  // L'ingrédient déjà choisi figure deux fois après l'ajout : dans le rendu du
  // serveur et dans le catalogue. On retire le premier — le doublon se verrait
  // dans la liste déroulante, et `value` retomberait sur celui du haut, hors de
  // l'ordre alphabétique.
  dedupe(selected) {
    if (!selected) return

    const duplicates = this.element.querySelectorAll(`option[value="${CSS.escape(selected)}"]`)
    if (duplicates.length > 1) duplicates[0].remove()
  }
}
