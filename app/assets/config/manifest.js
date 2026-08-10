//= link_tree ../images
//= link_directory ../stylesheets .css
//= link_tree ../../javascript .js
// Déclare app/assets/fonts pour que le .woff2 soit précompilé et obtienne une URL
// digérée. Sans cette ligne, asset_path résout en développement mais l'asset est
// absent de public/assets en production — l'échec ne se voit qu'après déploiement.
//= link_tree ../fonts
