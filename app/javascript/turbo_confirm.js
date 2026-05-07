// Remplace la boîte de confirmation native du navigateur (data-turbo-confirm)
// par le modal stylisé de l'application.
// Pas d'import Turbo — window.Turbo est défini par @hotwired/turbo-rails (chargé en premier).

const isDeletion = (message) => /supprimer|retirer/i.test(message)

const buildOverlay = (message) => {
  const overlay = document.createElement("div")
  overlay.className = "modal-overlay"
  overlay.innerHTML = `
    <div class="modal-container">
      <div class="modal-content">
        <div class="modal-header">
          <h3>Confirmation</h3>
        </div>
        <div class="modal-body">
          <p>${message}</p>
        </div>
        <div class="modal-actions">
          <button class="btn btn-secondary" data-action="cancel">Annuler</button>
          <button class="btn ${isDeletion(message) ? "btn-danger" : "btn-primary"}" data-action="confirm">
            ${isDeletion(message) ? "Supprimer" : "Confirmer"}
          </button>
        </div>
      </div>
    </div>
  `
  return overlay
}

const customConfirm = (message) => {
  return new Promise((resolve) => {
    const overlay = buildOverlay(message)
    document.body.appendChild(overlay)
    document.body.style.overflow = "hidden"

    const cleanup = (result) => {
      document.body.removeChild(overlay)
      document.body.style.overflow = ""
      document.removeEventListener("keydown", handleEscape)
      resolve(result)
    }

    const handleEscape = (e) => { if (e.key === "Escape") cleanup(false) }

    overlay.querySelector("[data-action='confirm']").addEventListener("click", () => cleanup(true))
    overlay.querySelector("[data-action='cancel']").addEventListener("click", () => cleanup(false))
    overlay.addEventListener("click", (e) => { if (e.target === overlay) cleanup(false) })
    document.addEventListener("keydown", handleEscape)
  })
}

// Turbo 8.x (turbo-rails 2.x) : l'API est Turbo.config.forms.confirm
// window.Turbo est garanti disponible ici car turbo-rails s'exécute en premier
if (window.Turbo?.config?.forms) {
  window.Turbo.config.forms.confirm = customConfirm
}
