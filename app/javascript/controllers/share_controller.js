import { Controller } from "@hotwired/stimulus"

/**
 * Partage d'une recette.
 *
 * Utilise l'API Web Share (native, mobile en priorité) lorsqu'elle est
 * disponible, avec un repli « copier le lien » dans le presse-papier sinon.
 * Un court toast confirme la copie.
 *
 * Usage :
 *   %button{ data: { controller: "share",
 *                    action: "share#share",
 *                    share_url_value: recipe_url(@recipe),
 *                    share_title_value: @recipe.name } }
 */
export default class extends Controller {
  static values = {
    url: String,
    title: String
  }

  share(event) {
    event.preventDefault()

    const url = this.urlValue || window.location.href

    // API Web Share (native) — Promise, rejetée si l'utilisateur annule.
    if (navigator.share) {
      navigator
        .share({ title: this.titleValue, url })
        .catch(() => {
          // Annulation utilisateur ou échec silencieux : rien à signaler.
        })
      return
    }

    // Repli : copie du lien dans le presse-papier.
    this.copyLink(url)
  }

  copyLink(url) {
    if (navigator.clipboard) {
      navigator.clipboard
        .writeText(url)
        .then(() => this.showToast("Lien copié !"))
        .catch(() => this.showToast("Impossible de copier le lien"))
    } else {
      this.showToast("Impossible de copier le lien")
    }
  }

  // Toast éphémère, auto-nettoyé. Créé à la volée pour rester autonome.
  showToast(message) {
    const toast = document.createElement("div")
    toast.className = "share-toast"
    toast.textContent = message
    document.body.appendChild(toast)

    // Force un reflow avant d'ajouter la classe visible (transition d'entrée).
    requestAnimationFrame(() => toast.classList.add("is-visible"))

    setTimeout(() => {
      toast.classList.remove("is-visible")
      toast.addEventListener("transitionend", () => toast.remove(), { once: true })
    }, 2000)
  }
}
