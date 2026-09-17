// Rafraîchissements en direct (Turbo 8, morph) : la page se met à jour sous les
// yeux de quelqu'un qui s'en sert peut-être — un rayon replié, une quantité en
// cours de correction, un mode d'affichage choisi. Le serveur ignore tout cela,
// et le morph ramènerait la page à ce qu'il connaît. Deux attributs l'en
// empêchent :
//
//   data-morph-keep="hidden aria-expanded"
//     Attributs pilotés par le JavaScript : le morph ne les modifie ni ne les
//     retire. Le reste de l'élément et ses enfants se mettent à jour.
//
//   data-morph-guard
//     Élément en cours de saisie — le focus est à l'intérieur, ou un champ a été
//     modifié : il n'est pas morphé du tout, et se mettra à jour au
//     rafraîchissement suivant.

const keptAttributes = (element) => (element.dataset?.morphKeep || "").split(/\s+/)

// Un champ modifié se reconnaît à l'écart entre sa valeur et celle du HTML reçu
const isDirty = (field) => {
  if (field instanceof HTMLSelectElement) {
    return Array.from(field.options).some((option) => option.selected !== option.defaultSelected)
  }
  return field.value !== field.defaultValue
}

const isBeingEdited = (element) =>
  element.contains(document.activeElement) ||
  Array.from(element.querySelectorAll("input, select, textarea")).some(isDirty)

document.addEventListener("turbo:before-morph-attribute", (event) => {
  if (keptAttributes(event.target).includes(event.detail.attributeName)) event.preventDefault()
})

document.addEventListener("turbo:before-morph-element", (event) => {
  const element = event.target
  if (element.hasAttribute?.("data-morph-guard") && isBeingEdited(element)) event.preventDefault()
})
