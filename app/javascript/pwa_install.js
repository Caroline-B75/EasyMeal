// Capture de l'événement d'installation PWA (Chrome / Edge, desktop et Android).
//
// Le navigateur émet « beforeinstallprompt » dès qu'il juge le site installable,
// souvent AVANT que Stimulus ait connecté ses controllers. Un controller qui se
// contenterait d'écouter l'événement le raterait donc au chargement initial :
// on le capte ici, à l'évaluation du module, et on le conserve pour le rejouer
// au clic de l'utilisateur.
//
// Les navigateurs sans cette API (Safari, Firefox) ne l'émettent jamais : le
// point d'entrée d'installation y reste simplement masqué.

let deferredPrompt = null

window.addEventListener("beforeinstallprompt", (event) => {
  // Neutralise la bannière native : c'est notre lien qui déclenche l'installation.
  event.preventDefault()
  deferredPrompt = event
  // Prévient les controllers déjà connectés ; ceux qui se connectent après
  // interrogeront isInstallable() à la place.
  window.dispatchEvent(new CustomEvent("pwa:installable"))
})

window.addEventListener("appinstalled", () => {
  deferredPrompt = null
  window.dispatchEvent(new CustomEvent("pwa:installed"))
})

export function isInstallable() {
  return deferredPrompt !== null
}

// Ouvre la boîte d'installation native du navigateur. L'événement capté n'est
// utilisable qu'une fois : on le libère après usage, le navigateur en émettra
// un nouveau s'il juge l'installation de nouveau pertinente.
export async function promptInstall() {
  if (!deferredPrompt) return false

  const event = deferredPrompt
  deferredPrompt = null
  await event.prompt()
  const { outcome } = await event.userChoice
  return outcome === "accepted"
}
