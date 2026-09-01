# Icônes de l'application

## Source de vérité

`public/icon.svg` — le wok paprika en vectoriel (2,9 Ko). C'est de lui que
partent toutes les refontes.

`icon-source.png` (2598×2598) est le raster d'origine, conservé ici comme
archive : le SVG en a été retracé au pixel près. Il n'est plus servi par le web
et n'est référencé nulle part.

## Fichiers dérivés et leur consommateur

| Fichier (dans `public/`) | Consommateur | Pourquoi il ne peut pas être un SVG |
|---|---|---|
| `favicon.ico` (16/32/48) | requête automatique `/favicon.ico` : barre de favoris, historique, nouvel onglet | le nom et le format sont imposés par la convention |
| `icon.svg` | onglet des navigateurs modernes | — |
| `apple-touch-icon-v4.png` | écran d'accueil iOS | iOS ignore le SVG sur cette balise |
| `icon-192-v4.png`, `icon-512-v4.png` | manifest PWA, `og:image` | Chrome n'installe pas une app aux icônes SVG ; les réseaux sociaux ne rendent pas le SVG |
| `icon-512-maskable-v4.png` | masque Android | **cadrage différent** : le motif est recentré dans la zone de sécurité |
| `icon-96-v4.png` | raccourcis du manifest | idem manifest |

## Refondre les icônes

1. Modifier `public/icon.svg`.
2. Regénérer les PNG à partir de lui, à chaque taille du tableau — et refaire
   à part le cadrage `maskable`, qui n'est pas une simple mise à l'échelle.
3. **Renommer** les PNG en `-v5` : ce sont des fichiers statiques non
   fingerprintés, et les caches d'icônes des OS sont tenaces. Répercuter le
   nouveau nom dans `app/views/pwa/manifest.json.erb`,
   `app/views/pwa/service-worker.js.erb` et
   `app/views/layouts/application.html.haml`.
4. Incrémenter `sw_revision` dans le service worker (voir le commentaire sur
   place : chaque refonte d'icônes y a sa ligne).

`favicon.ico` et `icon.svg` ne suivent pas la numérotation `-vN` : le premier a
un nom imposé, le second n'est pas dans l'app shell précaché.

⚠️ Ce poste n'a **aucun** outil de traitement d'image (ni ImageMagick, ni
Pillow, ni potrace). Les conversions se font à la main ou sur un autre poste.
