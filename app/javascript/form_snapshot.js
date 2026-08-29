// Rangement des instantanés de formulaire, dans le sessionStorage.
//
// Le sessionStorage est le bon tiroir pour une saisie en cours : propre à
// l'onglet, il ne ressort pas une vieille saisie dans une autre fenêtre, et il
// est oublié à la fermeture de l'onglet — un brouillon abandonné ne traîne pas.

const KEY_PREFIX = "easymeal.formSnapshot:"

export function readSnapshot(key) {
  try {
    return JSON.parse(sessionStorage.getItem(KEY_PREFIX + key))
  } catch {
    // Stockage refusé (navigation privée verrouillée) ou JSON corrompu : on
    // repart sans instantané plutôt que d'empêcher la saisie.
    return null
  }
}

// Écrit l'instantané. Rend false si le stockage l'a refusé — quota dépassé,
// typiquement, ce qu'une photo encodée suffit à provoquer : l'appelant peut
// alors réessayer avec moins.
export function writeSnapshot(key, snapshot) {
  try {
    sessionStorage.setItem(KEY_PREFIX + key, JSON.stringify(snapshot))
    return true
  } catch {
    return false
  }
}

export function forgetSnapshot(key) {
  try {
    sessionStorage.removeItem(KEY_PREFIX + key)
  } catch {
    // Stockage indisponible : il n'y avait rien à oublier.
  }
}
