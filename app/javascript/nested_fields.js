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
// N'existe que sur une ligne déjà en base : c'est ce qui distingue une
// suppression côté serveur d'un simple retrait du DOM.
export const RECORD_ID_SELECTOR = '[data-nested-form-target="recordId"]'

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

// Retire une ligne du formulaire. Une ligne jamais enregistrée quitte le DOM ;
// une ligne déjà en base reste soumise, marquée pour suppression et masquée —
// Rails ignore les enfants absents des params, la retirer du DOM ne la
// supprimerait donc pas.
//
// La règle est ici et non dans le contrôleur nested-form : le panneau d'import
// vide la liste entière, et la restauration d'une saisie repose des lignes
// qu'on avait retirées. Les trois doivent retirer une ligne de la même façon.
export function removeFields(fields) {
  const destroyInput = fields.querySelector(DESTROY_SELECTOR)

  if (fields.querySelector(RECORD_ID_SELECTOR) && destroyInput) {
    destroyInput.value = "1"
    fields.hidden = true
  } else {
    fields.remove()
  }
}
