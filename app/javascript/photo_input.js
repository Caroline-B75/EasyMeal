import { downscaleImage } from "image_downscale"

// Mécanique commune du choix d'une image — clic, dépôt, collage — vers un
// <input type="file"> : contrôle du fichier, réduction avant envoi, mémoire de
// la photo retenue par champ.
//
// Partagée par la zone photo du formulaire de recette (image_preview) et par la
// page d'import IA (import_source) : mêmes gestes, une seule implémentation.
// Chaque contrôleur garde en revanche sa mise en scène — aperçu, onglets,
// messages — qui, elle, lui est propre.

// Le champ fichier reste la seule source de vérité pour l'envoi du formulaire :
// un fichier déposé, collé — ou refabriqué par form-recovery après un
// rechargement de page — doit y être réinjecté via un DataTransfer.
export function assignFile(input, file) {
  const transfer = new DataTransfer()
  transfer.items.add(file)
  input.files = transfer.files
}

// Le champ porte déjà la liste des formats admis (attribut accept), que le
// sélecteur natif applique mais que le dépôt et le collage contournent : on la
// relit ici plutôt que de la redéclarer. Types exacts ("image/png") comme
// motifs génériques ("image/*") sont reconnus.
function acceptsFile(input, file) {
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

// Dépôt et collage contournent le filtre du sélecteur natif : sans ce mot,
// déposer un PDF donnerait l'impression que rien ne s'est passé.
const UNSUPPORTED_FILE_ERROR = "Format non accepté : choisis une image JPG, PNG ou WebP."

// Garde-fou dur : la réduction ci-dessous ramène une photo de téléphone bien
// en dessous des 10 Mo que Cloudinary accepte, mais c'est une optimisation qui
// peut échouer. Au-delà de ce poids, mieux vaut refuser tout de suite que
// téléverser en vain un fichier que le serveur rejettera.
const MAX_FILE_BYTES = 20 * 1024 * 1024
const OVERSIZED_FILE_ERROR = "Photo trop lourde (20 Mo maximum) : choisis une image plus légère."

// Dernière photo confiée à chaque champ. Une réduction qui se termine après un
// changement de photo est périmée : elle ne doit pas écraser la nouvelle.
const pendingPhotos = new WeakMap()

// Fait entrer une photo dans le champ fichier : contrôle du format et du poids,
// dépôt immédiat de l'original, puis remplacement par la version réduite dès
// qu'elle est prête. Retourne le motif du refus, ou null si la photo est prise.
//
// L'original est déposé d'abord parce que la réduction est asynchrone : un envoi
// lancé entre-temps doit partir avec la photo brute plutôt qu'à vide. onReady
// reçoit le fichier réellement retenu — c'est lui qu'un aperçu doit montrer.
export function acceptPhoto(input, file, onReady) {
  if (!acceptsFile(input, file)) return UNSUPPORTED_FILE_ERROR
  if (file.size > MAX_FILE_BYTES) return OVERSIZED_FILE_ERROR

  assignFile(input, file)
  pendingPhotos.set(input, file)

  downscaleImage(file).then((photo) => {
    if (pendingPhotos.get(input) !== file) return

    assignFile(input, photo)
    onReady(photo)
  })

  return null
}

// Oublie la photo confiée au champ : le champ se vide, et une réduction encore
// en cours ne viendra pas le remplir après coup.
export function forgetPhoto(input) {
  pendingPhotos.delete(input)
  input.value = ""
}
