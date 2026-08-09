// Piste colorée d'un <input type="range"> : la portion déjà parcourue prend la
// couleur primaire, le reste le fond neutre. Un navigateur ne sait pas styler
// cette moitié de piste en CSS seul — d'où ce dégradé recalculé à chaque
// mouvement.
//
// Partagée par les sliders « nombre de personnes » du formulaire de menu et des
// réglages du foyer : même composant visuel, une seule implémentation.
export function paintSliderTrack(slider) {
  const min = Number(slider.min)
  const max = Number(slider.max)
  const value = Number(slider.value)
  // Bornes égales (ou absentes) : aucune progression à représenter.
  const percent = max > min ? Math.round(((value - min) / (max - min)) * 100) : 0

  slider.style.background =
    `linear-gradient(to right, var(--color-primary) ${percent}%, var(--color-bg-tertiary) ${percent}%)`
}
