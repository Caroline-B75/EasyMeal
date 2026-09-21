import { Controller } from "@hotwired/stimulus"

/**
 * Compteur « achetés / total » d'un rayon de la liste de courses : même
 * replié, le rayon dit s'il y reste quelque chose à acheter.
 *
 * Le serveur le rend à jour (GroceryItemsHelper#grocery_section_count). Ce
 * contrôleur le recompte depuis la page quand une coche change sans lui : le
 * retour optimiste de grocery-check, et surtout hors ligne, au magasin, où la
 * réponse du serveur ne vient pas.
 *
 * Usage (sur le rayon, cf. menus/_grocery_section) :
 *   .grocery-section{ data: { controller: "grocery-progress",
 *                             action: "grocery-check:change->grocery-progress#refresh" } }
 *     %span{ data: { grocery_progress_target: "count", scope: "all" } }   (ou "mine")
 *       %span{ data: { part: "checked" } } … %span{ data: { part: "total" } }
 */
export default class extends Controller {
  static targets = ["count"]

  // Les contrôleurs s'enregistrent un à un : grocery-check a pu réappliquer une
  // coche en attente (file hors ligne) avant que celui-ci n'écoute ses événements.
  connect() {
    this.refresh()
  }

  refresh() {
    const items = Array.from(this.element.querySelectorAll(".grocery-item"))

    this.countTargets.forEach((count) => {
      // « Ma part » : mes articles et ceux que personne n'a pris, comme le filtre CSS
      const counted = count.dataset.scope === "mine"
        ? items.filter((item) => item.dataset.claim !== "other")
        : items
      const checked = counted.filter((item) => item.classList.contains("grocery-item--checked")).length

      count.querySelector("[data-part='checked']").textContent = checked
      count.querySelector("[data-part='total']").textContent = counted.length
      count.classList.toggle("grocery-section-count--done", checked === counted.length)
    })
  }
}
