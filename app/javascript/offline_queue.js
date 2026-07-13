// File d'attente hors-ligne pour les toggles de la liste de courses (R0.3).
//
// Objectif : permettre de cocher/décocher un article SANS réseau (usage en
// magasin) puis de synchroniser le serveur au retour de connexion.
//
// Conception (scope minimal) :
//   - La file est stockée dans localStorage sous forme d'un objet
//     { <url du PATCH> : <état "checked" souhaité> }.
//   - On indexe par URL : si l'utilisateur coche puis décoche le même article
//     hors-ligne, seule l'intention FINALE est conservée (last-write-wins).
//     Cela évite d'envoyer une rafale de requêtes contradictoires et limite
//     les conflits si la liste est régénérée entre-temps.

const STORAGE_KEY = "easymeal.groceryQueue"

// Événement émis à chaque changement de file (enqueue / purge) pour que
// l'indicateur réseau puisse rafraîchir son affichage.
export const QUEUE_CHANGED_EVENT = "grocery-queue:changed"

function readQueue() {
  try {
    return JSON.parse(localStorage.getItem(STORAGE_KEY)) || {}
  } catch {
    // localStorage indisponible (mode privé strict) ou JSON corrompu : on
    // repart d'une file vide plutôt que de planter.
    return {}
  }
}

function writeQueue(queue) {
  try {
    localStorage.setItem(STORAGE_KEY, JSON.stringify(queue))
  } catch {
    // Quota dépassé ou stockage bloqué : on ignore silencieusement, la
    // synchro hors-ligne est une amélioration, pas une garantie.
  }
}

function notifyChanged() {
  document.dispatchEvent(new CustomEvent(QUEUE_CHANGED_EVENT))
}

// Nombre de toggles en attente de synchronisation.
export function pendingCount() {
  return Object.keys(readQueue()).length
}

// État "checked" en attente pour une URL donnée, ou undefined si aucun.
// Permet de réhydrater l'affichage si la page est rechargée hors-ligne
// (le HTML servi par le cache reflète l'état de la dernière visite en ligne).
export function queuedState(url) {
  return readQueue()[url]
}

// Met un toggle en file d'attente (appelé quand le PATCH échoue pour cause réseau).
export function enqueueToggle(url, checked) {
  const queue = readQueue()
  queue[url] = checked
  writeQueue(queue)
  notifyChanged()
}

// Rejoue la file d'attente contre le serveur. Résout une fois toutes les
// tentatives faites. Les entrées non synchronisées (réseau toujours KO,
// erreur serveur) restent en file pour un prochain essai.
export async function replayQueue() {
  const snapshot = readQueue()
  const urls = Object.keys(snapshot)
  if (urls.length === 0) return

  // On relit le token CSRF depuis la meta du document AU MOMENT du replay :
  // le token mémorisé hors-ligne pourrait être périmé.
  const csrfToken = document.querySelector('meta[name="csrf-token"]')?.content

  // URLs effectivement traitées (à purger). On ne purge qu'à la fin pour ne
  // pas écraser un éventuel nouvel enqueue survenu pendant le replay.
  const done = []

  for (const url of urls) {
    try {
      const response = await fetch(url, {
        method: "PATCH",
        credentials: "same-origin",
        headers: {
          "Content-Type": "application/json",
          Accept: "text/vnd.turbo-stream.html, text/html, application/json",
          ...(csrfToken ? { "X-CSRF-Token": csrfToken } : {})
        },
        body: JSON.stringify({ grocery_item: { checked: snapshot[url] } })
      })

      // Succès OU item supprimé / liste régénérée (404) OU token/état invalide
      // (422) : dans tous ces cas l'entrée n'a plus de raison d'être rejouée.
      if (response.ok || response.status === 404 || response.status === 422) {
        done.push(url)
      }
      // Autres statuts (500, etc.) : on garde l'entrée pour réessayer plus tard.
    } catch {
      // Échec réseau : toujours hors-ligne, on conserve l'entrée.
    }
  }

  // Purge des entrées traitées, en préservant celles ajoutées entre-temps.
  const queue = readQueue()
  done.forEach((url) => delete queue[url])
  writeQueue(queue)
  notifyChanged()
}
