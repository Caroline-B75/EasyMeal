// Convention du contrôleur nested-form, partagée avec ceux qui posent une ligne
// sans passer par son bouton : le panneau d'import IA, la création d'un
// ingrédient à la volée, la restauration d'une saisie. Un <template> porte le
// modèle de ligne, où le placeholder NEW_RECORD tient la place de l'indice que
// Rails attend, et un conteneur reçoit les lignes.

export const TEMPLATE_SELECTOR = '[data-nested-form-target="template"]'
export const CONTAINER_SELECTOR = '[data-nested-form-target="container"]'
export const FIELDS_SELECTOR = '[data-nested-form-target="fields"]'
// Marque une ligne pour suppression : toujours soumise, mais retirée à la
// sauvegarde. Une ligne jamais enregistrée, elle, quitte simplement le DOM.
export const DESTROY_SELECTOR = '[data-nested-form-target="destroy"]'

// Indice de la prochaine ligne. L'horloge ne suffit pas à le rendre unique :
// deux lignes posées dans la même milliseconde — ce que fait la restauration
// d'une saisie, ou deux clics rapides du panneau d'import — porteraient le même
// indice, et Rails n'en verrait qu'une seule. On part de l'heure courante pour
// rester à l'écart des indices déjà rendus par le serveur (0, 1, 2…).
let nextIndex = Date.now()

// Clone un modèle de ligne et rend l'élément prêt à insérer.
export function buildFields(template) {
  const holder = document.createElement("div")
  holder.innerHTML = template.innerHTML.replace(/NEW_RECORD/g, nextIndex++).trim()

  return holder.firstElementChild
}
