// Configure your import map in config/importmap.rb. Read more: https://github.com/rails/importmap-rails
import "@hotwired/turbo-rails"
import "controllers"
import "turbo_confirm"

// Enregistrement du service worker (PWA).
// Garde de compatibilité : uniquement si le navigateur supporte l'API.
// On attend "load" pour ne pas concurrencer le rendu initial de la page.
if ("serviceWorker" in navigator) {
  window.addEventListener("load", () => {
    navigator.serviceWorker.register("/service-worker").catch((error) => {
      console.error("Échec de l'enregistrement du service worker :", error)
    })
  })
}
