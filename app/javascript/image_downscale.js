// Réduction d'une photo dans le navigateur, avant tout envoi.
//
// Une photo de téléphone (4000×3000, 5 à 15 Mo) part sinon telle quelle vers le
// serveur, qui l'encode en base64 pour l'API Claude : upload lent, requête
// énorme et tokens image gaspillés pour une précision dont la lecture d'un
// texte de recette n'a aucun besoin — ~1600 px sur le grand côté suffisent.
//
// Le canvas natif fait tout le travail : aucune dépendance. Et la réduction
// reste une optimisation, jamais un passage obligé — au moindre accroc (format
// exotique, mémoire), on rend le fichier d'origine plutôt que de bloquer
// l'import.

const MAX_EDGE = 1600
const JPEG_QUALITY = 0.85

// Rend le fichier à envoyer : la version réduite si l'image dépasse MAX_EDGE,
// le fichier d'origine sinon (ou en cas d'échec).
export async function downscaleImage(file) {
  try {
    const image = await decodeImage(file)
    const scale = MAX_EDGE / Math.max(image.naturalWidth, image.naturalHeight)
    if (scale >= 1) return file

    const blob = await encodeJpeg(drawScaled(image, scale))
    if (!blob) return file

    return new File([ blob ], jpegName(file.name), { type: "image/jpeg", lastModified: Date.now() })
  } catch {
    return file
  }
}

// Décode le fichier hors du DOM. Les navigateurs appliquent l'orientation EXIF
// à l'image décodée : une photo prise à la verticale reste dans le bon sens.
function decodeImage(file) {
  return new Promise((resolve, reject) => {
    const url = URL.createObjectURL(file)
    const image = new Image()

    image.onload = () => {
      URL.revokeObjectURL(url)
      resolve(image)
    }
    image.onerror = () => {
      URL.revokeObjectURL(url)
      reject(new Error(`Image illisible : ${file.name}`))
    }
    image.src = url
  })
}

// Redessine l'image à l'échelle voulue, ratio conservé.
function drawScaled(image, scale) {
  const canvas = document.createElement("canvas")
  canvas.width = Math.round(image.naturalWidth * scale)
  canvas.height = Math.round(image.naturalHeight * scale)

  const context = canvas.getContext("2d")
  // Le JPEG ignore la transparence : sans ce fond, les zones transparentes
  // d'une capture d'écran PNG ressortiraient en noir.
  context.fillStyle = "#ffffff"
  context.fillRect(0, 0, canvas.width, canvas.height)
  context.drawImage(image, 0, 0, canvas.width, canvas.height)

  return canvas
}

// Résout à null si l'encodage échoue — l'appelant garde alors l'original.
function encodeJpeg(canvas) {
  return new Promise((resolve) => canvas.toBlob(resolve, "image/jpeg", JPEG_QUALITY))
}

// Le contenu devient du JPEG : l'extension doit suivre, sinon le serveur reçoit
// une « capture.png » qui n'en est plus une.
function jpegName(name) {
  return `${name.replace(/\.[^.]+$/, "")}.jpg`
}
