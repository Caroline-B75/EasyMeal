// Mécanique commune du dépôt et du collage d'une image vers un
// <input type="file">.
//
// Partagée par la zone photo du formulaire de recette (image_preview) et par la
// page d'import IA (import_source) : mêmes gestes, une seule implémentation.
// Chaque contrôleur garde en revanche sa mise en scène — aperçu, onglets,
// messages — qui, elle, lui est propre.

// Le champ fichier reste la seule source de vérité pour l'envoi du formulaire :
// un fichier déposé ou collé doit y être réinjecté via un DataTransfer.
export function assignFile(input, file) {
  const transfer = new DataTransfer()
  transfer.items.add(file)
  input.files = transfer.files
}

// Le champ porte déjà la liste des formats admis (attribut accept), que le
// sélecteur natif applique mais que le dépôt et le collage contournent : on la
// relit ici plutôt que de la redéclarer. Types exacts ("image/png") comme
// motifs génériques ("image/*") sont reconnus.
export function acceptsFile(input, file) {
  if (!file) return false

  const patterns = input.accept.split(",").map((pattern) => pattern.trim()).filter(Boolean)
  if (patterns.length === 0) return true

  return patterns.some((pattern) => (
    pattern.endsWith("/*") ? file.type.startsWith(pattern.slice(0, -1)) : pattern === file.type
  ))
}

// Première image du presse-papiers, s'il y en a une : capture d'écran, ou image
// copiée depuis une page web. null sinon (texte collé, presse-papiers vide).
export function clipboardImage(event) {
  const files = event.clipboardData?.files
  if (!files) return null

  return Array.from(files).find((file) => file.type.startsWith("image/")) || null
}

// Lit un fichier image en data URL, pour l'afficher sans rien envoyer au
// serveur. Résout à null si la lecture échoue : un aperçu manquant ne doit
// jamais empêcher l'envoi du formulaire.
export function readImageUrl(file) {
  return new Promise((resolve) => {
    const reader = new FileReader()
    reader.onload = (event) => resolve(event.target.result)
    reader.onerror = () => resolve(null)
    reader.readAsDataURL(file)
  })
}
