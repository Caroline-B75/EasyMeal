# Requetes a passer pour appliquer les recommandations UX/UI EasyMeal

Ce fichier contient des requetes pretes a copier-coller dans Claude Code pour mettre en place progressivement toutes les recommandations UX/UI. Chaque requete est volontairement limitee a un perimetre coherent, avec les fichiers de contexte, l'objectif, les vues a verifier et un nom de commit court.

> Important : respecter les instructions projet EasyMeal. Ne pas lancer Rails console. Les validations Rails doivent etre lancees par l'utilisateur dans le terminal Ubuntu/WSL si necessaire.

---

## 1. Nettoyer la charte graphique globale

### Contexte fichiers

- `app/assets/stylesheets/variables.css`
- `app/assets/stylesheets/components.css`
- `app/assets/stylesheets/layouts.css`
- `app/assets/stylesheets/global.css`
- `app/assets/stylesheets/home.css`
- `app/assets/stylesheets/menus.css`
- `app/assets/stylesheets/recipes.css`
- `app/assets/stylesheets/tags.css`
- `app/assets/stylesheets/grocery_items.css`

### Objectif

Faire respecter strictement la charte Slate Craft Premium : anthracite comme couleur principale, ambre reserve aux badges "de saison" et aux etoiles de notation, pas de rouge/orange hardcode pour l'interface courante, pas de violet decoratif.

### Demande pour Claude Code

Analyse tous les CSS listes ci-dessus et remplace les couleurs hardcodees qui contredisent la charte EasyMeal par des variables CSS existantes ou par de nouvelles variables neutres ajoutees dans `variables.css` si necessaire. En particulier :

- supprimer les usages directs de `#D73A49`, `#FF9E4D`, `#7C3AED` et couleurs similaires non conformes ;
- remplacer les etats actifs de navigation en ambre par un style anthracite/neutre ;
- garder l'ambre uniquement pour les etoiles de notation et les badges/indicateurs explicitement saisonniers ;
- rendre les actions destructives moins agressives visuellement lorsque ce sont des icones d'action : icones en `var(--color-ink-4)`, hover sobre, confirmation avant suppression ;
- conserver les vraies alertes d'erreur en couleur danger quand il s'agit de feedback systeme ou validation de formulaire ;
- eviter les refontes structurelles dans cette requete, uniquement coherence visuelle et variables.

### Vues a checker

- Navigation connectee et non connectee
- `/recipes`
- `/recipes/:id`
- `/menus`
- `/menus/new`
- `/menus/:id`
- `/menus/:id/grocery`
- `/ingredients`
- `/tags`
- Pages Devise connexion/inscription

### Nom de commit court

`style: harmonize color system`

---

## 2. Remplacer les emojis UI par des icones coherentes

### Contexte fichiers

- `app/helpers/application_helper.rb`
- `app/views/recipes/index.html.haml`
- `app/views/recipes/_draft_status_bar.html.haml`
- `app/views/recipes/_favorite_button.html.haml`
- `app/views/recipes/_draft_button.html.haml`
- `app/views/recipes/_form.html.haml`
- `app/views/recipes/_preparation_fields.html.haml`
- `app/views/menus/index.html.haml`
- `app/views/menus/_grocery_item.html.haml`
- `app/views/recipe_imports/new.html.haml`
- `app/views/recipe_drafts/index.html.haml`
- `app/views/tags/_tags_list.html.haml`

### Objectif

Remplacer les emojis et caracteres symboliques utilises comme elements d'interface par des icones SVG coherentes avec le design system, accessibles et stylables.

### Demande pour Claude Code

Remplace les emojis et symboles UI visibles par des appels au helper `svg_icon` ou par les helpers d'icones deja utilises dans le projet. Sont concernes notamment : loupe, coeur favori, checklist/menu draft, croix fermeture, validation, ajout, photo, lien, horloge, assiette/etat vide, cuisson/etat vide.

Contraintes :

- conserver les textes visibles utiles ;
- ajouter des `aria-label` aux boutons icones si le texte n'est pas visible ;
- ne pas remplacer les etoiles de notation si elles sont generees volontairement par `rating_stars` ;
- garder une taille d'icone coherente avec les boutons existants ;
- ne pas introduire de nouvelle librairie.

### Vues a checker

- `/recipes`
- `/recipes/:id`
- `/menus`
- `/menus/:id/grocery`
- `/recipe_imports/new`
- `/recipe_drafts`
- `/tags`
- Formulaire de recette new/edit

### Nom de commit court

`style: replace ui emojis`

---

## 3. Convertir les vues Devise ERB en HAML

### Contexte fichiers

- `app/views/devise/sessions/new.html.erb`
- `app/views/devise/registrations/new.html.erb`
- `app/views/devise/passwords/new.html.erb`
- `app/views/devise/shared/_links.html.erb`
- `app/assets/stylesheets/authentication.css`

### Objectif

Respecter la convention projet : toutes les vues doivent etre en HAML. Conserver le rendu existant tout en ameliorant legerement la lisibilite du markup.

### Demande pour Claude Code

Convertis les vues Devise ERB listees en `.html.haml`, puis supprime les fichiers ERB correspondants. Le rendu et les classes CSS doivent rester compatibles avec `authentication.css`.

Contraintes :

- conserver `simple_form_for`, les champs, les classes et les comportements Devise ;
- ne pas changer la logique d'authentification ;
- conserver `content_for :head` pour charger `authentication.css` ;
- verifier que les partials Devise continuent d'etre rendus correctement ;
- ameliorer les labels/placeholders uniquement si c'est sans risque fonctionnel.

### Vues a checker

- `/users/sign_in`
- `/users/sign_up`
- `/users/password/new`
- Navigation non connectee depuis l'accueil

### Nom de commit court

`refactor: convert devise to haml`

---

## 4. Harmoniser les composants de base

### Contexte fichiers

- `app/assets/stylesheets/components.css`
- `app/assets/stylesheets/authentication.css`
- `app/assets/stylesheets/recipes.css`
- `app/assets/stylesheets/menus.css`
- `app/assets/stylesheets/tags.css`
- `app/assets/stylesheets/ingredients.css`
- `app/views/shared/_delete_confirmation_modal.html.haml`
- `app/views/shared/_flash.html.haml`

### Objectif

Reduire les variantes dupliquees de boutons, cards, badges, formulaires et modales pour obtenir une interface plus coherente et plus maintenable.

### Demande pour Claude Code

Fais un refactoring CSS cible pour consolider les composants communs : boutons, boutons icones, badges, cards, empty states, modales, champs de formulaire. Deplace ou harmonise les declarations generiques dans `components.css` et laisse dans les CSS metier uniquement ce qui est vraiment specifique a la vue.

Contraintes :

- ne pas faire une refonte visuelle massive ;
- conserver les noms de classes utilises par les vues lorsque possible ;
- eviter de casser les styles specifiques `rs-*`, `mc-*`, `mi-*`, `mn-*` ;
- supprimer les doublons evidents de `.btn`, `.btn-danger`, `.icon-btn`, `.empty-state` ;
- conserver les tailles tactiles minimum sur mobile.

### Vues a checker

- Toutes les pages avec boutons : recettes, menus, ingredients, tags, auth
- Modale de suppression sur ingredients/tags/recettes/menus
- Flash messages apres une action Turbo ou formulaire

### Nom de commit court

`refactor: consolidate ui components`

---

## 5. Ameliorer l'accueil visiteur et connecte

### Contexte fichiers

- `app/views/home/index.html.haml`
- `app/views/home/_vitrine.html.haml`
- `app/views/home/_dashboard.html.haml`
- `app/views/home/_dashboard_active.html.haml`
- `app/views/home/_dashboard_draft.html.haml`
- `app/assets/stylesheets/home.css`
- `app/helpers/home_helper.rb`
- `app/controllers/home_controller.rb`

### Objectif

Rendre l'accueil plus utile et plus produit : la vitrine doit montrer concretement la promesse EasyMeal, et l'accueil connecte doit devenir un mini tableau de bord contextuel plutot qu'une simple liste de CTA.

### Demande pour Claude Code

Ameliore l'accueil avec deux experiences distinctes :

- visiteur : conserver le hero image, mais ajouter un signal concret du produit dans le premier ecran, par exemple un apercu compact "menu -> personnalisation -> liste de courses" ;
- utilisateur connecte avec brouillon : afficher le nom du brouillon, nombre de repas, regime, personnes et action principale "Reprendre" ;
- utilisateur connecte avec menu actif : afficher le menu actif, nombre de repas, acces liste de courses, progression si l'information est disponible sans requete lourde ;
- utilisateur connecte sans menu : guider vers la creation d'un menu avec un CTA principal et un acces catalogue secondaire.

Contraintes :

- rester dans le style Slate Craft Premium ;
- eviter une landing page trop marketing pour l'utilisateur connecte ;
- mobile-first ;
- ne pas ajouter de nouvelle dependance ;
- garder les images existantes.

### Vues a checker

- `/` non connecte
- `/` connecte sans menu
- `/` connecte avec brouillon
- `/` connecte avec menu actif
- Mobile largeur 375px et desktop

### Nom de commit court

`feat: improve home dashboard`

---

## 6. Clarifier la navigation desktop/mobile

### Contexte fichiers

- `app/views/layouts/application.html.haml`
- `app/assets/stylesheets/layouts.css`
- `app/javascript/controllers/menu_controller.js`
- `app/helpers/application_helper.rb`
- `app/helpers/context_bar_helper.rb`
- `app/views/shared/_context_bar.html.haml`
- `app/assets/stylesheets/context_bar.css`

### Objectif

Rendre la navigation plus lisible, surtout sur mobile, et assurer que le menu profil ne soit pas confondu avec la navigation principale.

### Demande pour Claude Code

Ameliore le header principal :

- separer clairement le bouton profil et le bouton menu mobile, ou rendre le bouton actuel explicitement identifiable comme menu ;
- conserver les liens desktop existants ;
- ameliorer le dropdown mobile pour afficher les liens principaux avec un ordre logique ;
- supprimer l'usage de l'ambre pour l'etat actif ;
- verifier les focus visibles et `aria-expanded`/`aria-controls` si pertinent ;
- conserver le logo tel quel.

Ameliore aussi la context bar si necessaire pour que breadcrumbs/back links soient coherents sur mobile.

### Vues a checker

- Header connecte desktop
- Header connecte mobile
- Header non connecte
- Pages avec context bar : recettes show, menus new/edit, ingredients new/edit/show, tags edit

### Nom de commit court

`feat: refine main navigation`

---

## 7. Simplifier et hierarchiser le catalogue de recettes

### Contexte fichiers

- `app/views/recipes/index.html.haml`
- `app/views/recipes/_favorite_button.html.haml`
- `app/views/recipes/_draft_button.html.haml`
- `app/views/recipes/_draft_status_bar.html.haml`
- `app/assets/stylesheets/recipes.css`
- `app/javascript/controllers/recipe_filter_controller.js`
- `app/helpers/recipes_helper.rb`
- `app/controllers/recipes_controller.rb`

### Objectif

Reduire la charge cognitive du catalogue tout en gardant la puissance des filtres. Les cartes doivent etre plus scannables et les filtres plus faciles a utiliser.

### Demande pour Claude Code

Ameliore la page catalogue :

- rendre la sidebar desktop moins dense : filtres principaux visibles, tags groupes en accordions ou sections mieux espacees ;
- rendre les filtres actifs plus lisibles et faciles a retirer ;
- remplacer les emojis par icones si ce n'est pas deja fait ;
- ameliorer les cartes recettes : temps total visible, regime lisible, note/reviews mieux alignes, tags limites proprement ;
- rendre le bouton mobile "Filtres" plus clair, avec compteur stable ;
- ameliorer la barre de brouillon menu pour qu'elle soit plus actionnable sans prendre trop de place.

Contraintes :

- conserver Turbo Frame et Stimulus existants ;
- ne pas changer les parametres de filtres ni les routes ;
- mobile-first ;
- eviter les cards imbriquees.

### Vues a checker

- `/recipes` sans filtre
- `/recipes?query=...`
- `/recipes` avec favoris, tags, regime, saison
- Mobile : ouverture/fermeture drawer filtres
- Utilisateur connecte avec brouillon menu

### Nom de commit court

`feat: polish recipe catalog`

---

## 8. Ameliorer la fiche recette

### Contexte fichiers

- `app/views/recipes/show.html.haml`
- `app/views/recipes/_review_form.html.haml`
- `app/views/recipes/_review_card.html.haml`
- `app/views/recipes/_favorite_button.html.haml`
- `app/assets/stylesheets/recipes.css`
- `app/javascript/controllers/servings_controller.js`
- `app/javascript/controllers/rating_controller.js`
- `app/helpers/recipes_helper.rb`

### Objectif

Renforcer la valeur pratique de la fiche recette : ingredients faciles a consulter, actions principales evidentes, avis mieux integres, comportement mobile plus ergonomique.

### Demande pour Claude Code

Ameliore la fiche recette :

- rendre le panneau ingredients sticky sur desktop si possible sans casser le responsive ;
- rendre les actions principales plus claires : ajouter au menu, favori, partage ;
- si le bouton partage n'a pas de comportement, implementer une action native simple via Stimulus ou retirer/neutraliser proprement le bouton ;
- ameliorer l'espacement des etapes de preparation et la lisibilite mobile ;
- ameliorer le formulaire d'avis avec libelle clair, validation visuelle, et etoiles plus accessibles ;
- conserver le style hero editorial existant.

Contraintes :

- ne pas changer le modele de donnees ;
- ne pas ajouter de dependance ;
- respecter les couleurs de la charte ;
- garder les avis et favoris fonctionnels avec Turbo.

### Vues a checker

- `/recipes/:id` avec photo
- `/recipes/:id` sans photo
- Recette avec avis
- Recette sans avis
- Mobile : ingredients, actions, avis

### Nom de commit court

`feat: improve recipe show ux`

---

## 9. Rendre le formulaire recette plus progressif

### Contexte fichiers

- `app/views/recipes/new.html.haml`
- `app/views/recipes/edit.html.haml`
- `app/views/recipes/_form.html.haml`
- `app/views/recipes/_preparation_fields.html.haml`
- `app/views/recipes/_ai_ingredients_panel.html.haml`
- `app/views/ingredients/_quick_form.html.haml`
- `app/assets/stylesheets/recipes.css`
- `app/javascript/controllers/nested_form_controller.js`
- `app/javascript/controllers/slideout_controller.js`
- `app/javascript/controllers/image_preview_controller.js`

### Objectif

Rendre la creation/edition de recette moins intimidante, surtout pour les brouillons IA, sans perdre les fonctionnalites admin.

### Demande pour Claude Code

Refonds legerement le formulaire recette en sections progressives :

- conserver toutes les informations actuelles ;
- mieux separer visuellement infos generales, caracteristiques, tags, photo, ingredients, preparation ;
- pour les brouillons IA, afficher un resume de validation ou les points a completer si les donnees existent deja ;
- rendre les champs ingredients plus lisibles sur mobile ;
- ameliorer le bouton "Creer un nouvel ingredient" dans le slideout ;
- remplacer les symboles `+`, `x`, `✓` par icones coherentes si pas encore fait.

Contraintes :

- ne pas casser les nested fields ;
- ne pas changer les parametres attendus par le controller ;
- ne pas introduire d'accordeon complexe si cela met en risque la sauvegarde ;
- garder le formulaire utilisable sans JavaScript critique sauf les comportements deja existants.

### Vues a checker

- `/recipes/new`
- `/recipes/:id/edit`
- Edition d'un brouillon IA depuis `/recipe_drafts`
- Ajout/suppression d'ingredients imbriques
- Creation rapide d'ingredient depuis slideout

### Nom de commit court

`feat: improve recipe form ux`

---

## 10. Harmoniser generation et regeneration de menu

### Contexte fichiers

- `app/views/menus/new.html.haml`
- `app/views/menus/edit.html.haml`
- `app/views/menus/_form_generate.html.haml`
- `app/views/menus/_form_regenerate.html.haml`
- `app/assets/stylesheets/menus.css`
- `app/javascript/controllers/menu_generate_controller.js`
- `app/helpers/menus_helper.rb`
- `app/controllers/menus_controller.rb`

### Objectif

Donner l'impression d'un seul parcours coherent pour creer ou regenerer un menu. Eviter deux designs de formulaire differents pour des choix similaires.

### Demande pour Claude Code

Mutualise ou harmonise les formulaires de generation et regeneration :

- meme rendu des regimes alimentaires ;
- meme type de controle pour le nombre de personnes ;
- meme type de controle pour le nombre de repas ;
- resume clair avant validation, y compris sur creation initiale ;
- confirmation plus explicite uniquement pour la regeneration car elle remplace les recettes ;
- suppression des couleurs hors charte dans les icones de regime.

Contraintes :

- conserver les routes `menus_path` et `regenerate_menu_path(menu)` ;
- conserver les valeurs par defaut actuelles ;
- ne pas changer les services de generation ;
- mobile-first.

### Vues a checker

- `/menus/new`
- `/menus/:id/edit` pour un menu draft
- Generation d'un menu
- Regeneration d'un menu draft
- Mobile 375px

### Nom de commit court

`feat: unify menu generation`

---

## 11. Ameliorer la liste Mes menus

### Contexte fichiers

- `app/views/menus/index.html.haml`
- `app/views/menus/_history_card.html.haml`
- `app/assets/stylesheets/menus.css`
- `app/javascript/controllers/menus_index_controller.js`
- `app/helpers/menus_helper.rb`
- `app/controllers/menus_controller.rb`

### Objectif

Rendre la page Mes menus plus lisible et mieux exploiter l'espace desktop. Clarifier les etats brouillon, actif, historique et les actions disponibles.

### Demande pour Claude Code

Ameliore `/menus` :

- remplacer les largeurs trop etroites par un container responsive plus confortable ;
- renforcer la hierarchie entre brouillon, menu actif et historique ;
- rendre les actions principales plus evidentes : continuer, voir menu, voir liste de courses ;
- garder les actions destructives secondaires et sobres ;
- ameliorer les empty states ;
- verifier l'expansion des cartes historiques sur mobile.

Contraintes :

- conserver le comportement Stimulus existant ;
- ne pas changer les statuts ni la logique draft/active/archive ;
- ne pas afficher trop de contenu dans l'historique par defaut.

### Vues a checker

- `/menus` sans menu
- `/menus` avec draft seulement
- `/menus` avec menu actif
- `/menus` avec historique long
- Mobile : expansion draft/historique

### Nom de commit court

`feat: improve menus index`

---

## 12. Ameliorer la personnalisation du menu draft

### Contexte fichiers

- `app/views/menus/show.html.haml`
- `app/views/menus/_draft_view.html.haml`
- `app/views/menus/_menu_recipe_card.html.haml`
- `app/views/menus/_active_view.html.haml`
- `app/views/menus/_menu_recipe_card_readonly.html.haml`
- `app/assets/stylesheets/menus.css`
- `app/javascript/controllers/menu_customize_controller.js`
- `app/javascript/controllers/auto_submit_controller.js`

### Objectif

Rendre la personnalisation du menu plus claire, plus accessible et meilleure sur mobile.

### Demande pour Claude Code

Ameliore la vue menu draft :

- conserver le drag/drop existant ;
- ajouter une alternative accessible au reordonnancement si simple : boutons monter/descendre ou controles visibles au focus ;
- clarifier les actions de chaque carte : remplacer, nombre de personnes, retirer ;
- ajouter tooltips ou libelles accessibles aux boutons icones ;
- rendre le CTA "Valider et generer la liste de courses" sticky ou plus visible lorsque le menu contient des repas ;
- ameliorer l'etat vide et le slot d'ajout.

Contraintes :

- ne pas changer les routes Turbo existantes ;
- ne pas casser `reorder_menu_menu_recipes_path` ;
- conserver la grille compacte desktop ;
- mobile-first.

### Vues a checker

- `/menus/:id` pour un menu draft avec repas
- `/menus/:id` pour un draft vide
- Remplacer un repas
- Retirer un repas
- Changer le nombre de personnes
- Reordonner desktop et mobile

### Nom de commit court

`feat: improve draft menu ux`

---

## 13. Ameliorer la liste de courses

### Contexte fichiers

- `app/views/menus/grocery.html.haml`
- `app/views/menus/_grocery_list.html.haml`
- `app/views/menus/_grocery_section.html.haml`
- `app/views/menus/_grocery_item.html.haml`
- `app/assets/stylesheets/grocery_items.css`
- `app/assets/stylesheets/menus.css`
- `app/javascript/controllers/grocery_sections_controller.js`
- `app/javascript/controllers/grocery_accordion_controller.js`
- `app/javascript/controllers/grocery_check_controller.js`
- `app/javascript/controllers/grocery_edit_qty_controller.js`
- `app/controllers/grocery_items_controller.rb`
- `app/controllers/menus_controller.rb`

### Objectif

Transformer la liste de courses en outil quotidien plus efficace : progression, actions rapides, meilleure ergonomie mobile, ajout manuel moins encombrant.

### Demande pour Claude Code

Ameliore la page liste de courses :

- ajouter un header utile avec nom du menu si disponible, nombre total d'articles et articles restants ;
- ajouter une action pour masquer/afficher les articles coches si possible cote Stimulus sans nouvelle route ;
- rendre "Tout fermer" plus clair et prevoir l'etat inverse "Tout ouvrir" ;
- rendre l'edition de quantite plus decouvrable ;
- transformer l'ajout manuel en bloc plus compact, eventuellement deployable ;
- conserver les sections par rayon et les toggles d'items existants.

Contraintes :

- ne pas changer le modele de donnees ;
- ne pas casser les Turbo Frames d'items ;
- mobile-first pour usage en magasin ;
- garder les boutons tactiles confortables.

### Vues a checker

- `/menus/:id/grocery` avec liste pleine
- Liste avec articles coches et non coches
- Liste vide
- Ajout manuel d'un article
- Edition de quantite
- Mobile 375px

### Nom de commit court

`feat: improve grocery list`

---

## 14. Ameliorer les vues ingredients

### Contexte fichiers

- `app/views/ingredients/index.html.haml`
- `app/views/ingredients/show.html.haml`
- `app/views/ingredients/new.html.haml`
- `app/views/ingredients/edit.html.haml`
- `app/views/ingredients/_form.html.haml`
- `app/assets/stylesheets/ingredients.css`
- `app/javascript/controllers/ingredient_form_controller.js`
- `app/controllers/ingredients_controller.rb`

### Objectif

Rendre la gestion des ingredients plus lisible et moins back-office, sans perdre l'efficacite admin.

### Demande pour Claude Code

Ameliore les vues ingredients :

- remplacer le container trop etroit par une largeur responsive confortable ;
- ameliorer la zone filtres avec un rendu plus compact et plus clair ;
- ameliorer le rendu des mois de saison : resume plus lisible, badges stables, cas "Toute l'annee" visible ;
- dans le formulaire, ajouter des actions rapides pour les mois si possible : toute l'annee, aucun, saison actuelle, ou au minimum mieux grouper les mois ;
- clarifier l'unite de base en lecture seule ;
- conserver les policies et actions admin.

Contraintes :

- ne pas changer les enums ni les params attendus ;
- ne pas ajouter de dependance ;
- garder le mode table desktop et cartes mobile si pertinent.

### Vues a checker

- `/ingredients`
- `/ingredients?query=...`
- `/ingredients/new`
- `/ingredients/:id/edit`
- `/ingredients/:id`
- Mobile liste ingredients

### Nom de commit court

`feat: improve ingredients ui`

---

## 15. Ameliorer les tags admin

### Contexte fichiers

- `app/views/tags/index.html.haml`
- `app/views/tags/edit.html.haml`
- `app/views/tags/_tags_list.html.haml`
- `app/assets/stylesheets/tags.css`
- `app/javascript/controllers/tag_inline_controller.js`
- `app/controllers/tags_controller.rb`
- `app/models/tag.rb`

### Objectif

Rendre la gestion des tags plus comprehensible : les tags sont des outils de classement, il faut mieux voir leur type et leur usage.

### Demande pour Claude Code

Ameliore les vues tags :

- si `tag_type` est disponible, grouper ou afficher clairement le type de tag ;
- rendre le nombre de recettes associees plus visible ;
- ameliorer l'edition inline avec icones SVG accessibles au lieu de `✓` et `×` ;
- rendre la suppression sobre et confirmee ;
- harmoniser la page edit avec les autres formulaires admin.

Contraintes :

- ne pas changer la logique d'autorisation ;
- ne pas casser l'edition inline Turbo ;
- ne pas ajouter de creation de tag si la route n'existe pas.

### Vues a checker

- `/tags`
- Edition inline d'un tag
- Suppression d'un tag
- `/tags/:id/edit`
- Mobile tags en cartes

### Nom de commit court

`feat: improve tags admin`

---

## 16. Ameliorer import IA et brouillons importes

### Contexte fichiers

- `app/views/recipe_imports/new.html.haml`
- `app/views/recipe_drafts/index.html.haml`
- `app/views/recipes/edit.html.haml`
- `app/views/recipes/_ai_ingredients_panel.html.haml`
- `app/assets/stylesheets/recipes.css`
- `app/javascript/controllers/import_source_controller.js`
- `app/controllers/recipe_imports_controller.rb`
- `app/controllers/recipe_drafts_controller.rb`

### Objectif

Rendre le workflow IA plus rassurant : importer, attendre, verifier, completer, publier.

### Demande pour Claude Code

Ameliore l'import IA :

- remplacer les onglets emoji par des onglets iconifies coherents ;
- ajouter un feedback visible pendant la soumission si le controller Stimulus le permet ;
- afficher le nom du fichier selectionne ou un petit etat de selection pour la photo ;
- clarifier que l'import cree un brouillon a verifier avant publication ;
- ameliorer la liste des brouillons : source, date, statut de completude si calculable simplement, action principale "Completer / Valider", suppression secondaire ;
- conserver le flux actuel URL/photo.

Contraintes :

- ne pas changer le service IA ;
- ne pas ajouter de nouvelle dependance ;
- ne pas faire d'appel externe cote front ;
- garder `multipart: true` et `turbo: false` si necessaire.

### Vues a checker

- `/recipe_imports/new`
- Selection URL
- Selection photo
- Soumission import
- `/recipe_drafts`
- Edition d'un brouillon importe

### Nom de commit court

`feat: improve ai import ux`

---

## 17. Renforcer l'accessibilite des interactions

### Contexte fichiers

- `app/views/shared/_delete_confirmation_modal.html.haml`
- `app/views/shared/_context_bar.html.haml`
- `app/views/layouts/application.html.haml`
- `app/views/menus/_grocery_section.html.haml`
- `app/views/menus/_grocery_item.html.haml`
- `app/views/menus/_menu_recipe_card.html.haml`
- `app/views/recipes/index.html.haml`
- `app/assets/stylesheets/components.css`
- `app/assets/stylesheets/layouts.css`
- `app/assets/stylesheets/context_bar.css`
- `app/javascript/controllers/modal_controller.js`
- `app/javascript/controllers/menu_controller.js`
- `app/javascript/controllers/grocery_accordion_controller.js`
- `app/javascript/controllers/menu_customize_controller.js`

### Objectif

Ameliorer l'accessibilite clavier et lecteur d'ecran sur les composants interactifs principaux.

### Demande pour Claude Code

Passe en revue les composants interactifs listes et ameliore l'accessibilite :

- boutons icones avec `aria-label` explicite ;
- dropdown navigation avec `aria-expanded` et focus visible ;
- modale suppression avec role/dialog, titre associe et fermeture accessible ;
- accordions liste de courses avec `aria-expanded` ;
- filtres drawer mobile avec libelles et focus visible ;
- drag/drop menu avec alternative ou au minimum libelles d'action clairs ;
- focus styles coherents dans `components.css`.

Contraintes :

- ne pas casser les controllers Stimulus ;
- eviter les gros changements de structure ;
- garder le rendu visuel sobre.

### Vues a checker

- Header mobile
- Modale suppression ingredients/tags/menus
- `/recipes` drawer filtres mobile
- `/menus/:id` draft
- `/menus/:id/grocery`
- Navigation au clavier sur les pages principales

### Nom de commit court

`feat: improve accessibility`

---

## 18. Passer une verification responsive globale

### Contexte fichiers

- `app/assets/stylesheets/layouts.css`
- `app/assets/stylesheets/home.css`
- `app/assets/stylesheets/recipes.css`
- `app/assets/stylesheets/menus.css`
- `app/assets/stylesheets/grocery_items.css`
- `app/assets/stylesheets/ingredients.css`
- `app/assets/stylesheets/tags.css`
- Toutes les vues principales modifiees dans les requetes precedentes

### Objectif

Corriger les derniers problemes responsive apres les ameliorations : texte qui deborde, boutons trop petits, containers trop etroits/larges, chevauchements, scroll horizontal non voulu.

### Demande pour Claude Code

Fais une passe responsive globale sur les vues principales :

- verifier mobile 375px, tablette 768px, desktop 1280px ;
- supprimer les largeurs fixes problematiques ;
- garantir des touch targets d'au moins 44px pour actions principales ;
- verifier que les boutons et textes ne se chevauchent pas ;
- conserver les tableaux admin en mode cartes mobile ou scroll horizontal controle ;
- corriger uniquement les problemes constates dans les fichiers CSS concernes.

Contraintes :

- ne pas refaire le design ;
- ne pas modifier la logique Rails ;
- privilegier les corrections CSS ciblees.

### Vues a checker

- `/`
- `/recipes`
- `/recipes/:id`
- `/recipes/new`
- `/menus`
- `/menus/new`
- `/menus/:id`
- `/menus/:id/grocery`
- `/ingredients`
- `/tags`
- `/recipe_imports/new`
- Pages Devise

### Nom de commit court

`style: responsive polish`

---

## 19. Nettoyer le CSS mort et les doublons apres refonte

### Contexte fichiers

- `app/assets/stylesheets/application.css`
- `app/assets/stylesheets/components.css`
- `app/assets/stylesheets/authentication.css`
- `app/assets/stylesheets/context_bar.css`
- `app/assets/stylesheets/global.css`
- `app/assets/stylesheets/grocery_items.css`
- `app/assets/stylesheets/recipes.css`
- `app/assets/stylesheets/menus.css`
- `app/assets/stylesheets/layouts.css`
- `app/assets/stylesheets/ingredients.css`
- `app/assets/stylesheets/home.css`
- `app/assets/stylesheets/tags.css`

### Objectif

Supprimer les restes de classes obsoletes et les doublons CSS crees par l'historique des refontes, sans casser les vues.

### Demande pour Claude Code

Analyse les CSS et les vues pour supprimer ou consolider le CSS manifestement mort ou duplique :

- classes commentees comme supprimees mais encore presentes si inutiles ;
- anciennes variantes `.btn-*`, `.meal-card-*`, `.recipe-*` non referencees ;
- doublons de `.btn`, `.btn-danger`, `.empty-state`, `.icon-btn` ;
- couleurs hardcodees residuelles ;
- commentaires obsoletes ou trompeurs.

Contraintes :

- verifier par recherche avant suppression ;
- ne pas supprimer une classe si elle est utilisee par Stimulus, Turbo ou du JS ;
- ne pas faire de reformatage massif ;
- garder les CSS separes par domaine.

### Vues a checker

- Toutes les vues principales
- Actions Stimulus : filtres recettes, menu dropdown, modal, grocery accordion, menu customize, nested form

### Nom de commit court

`refactor: prune unused css`

---

## 20. Faire une passe finale de coherence UX et microcopy

### Contexte fichiers

- `app/views/home/**/*.haml`
- `app/views/recipes/**/*.haml`
- `app/views/menus/**/*.haml`
- `app/views/ingredients/**/*.haml`
- `app/views/tags/**/*.haml`
- `app/views/recipe_imports/**/*.haml`
- `app/views/recipe_drafts/**/*.haml`
- `app/views/devise/**/*.haml`
- `config/locales/**/*.yml`

### Objectif

Uniformiser le ton, les libelles d'action et les messages utilisateur pour que l'application paraisse finie et coherente.

### Demande pour Claude Code

Fais une passe de microcopy UX :

- harmoniser les actions : creer, ajouter, modifier, supprimer, valider, reprendre ;
- eviter les formulations trop longues sur boutons ;
- clarifier les empty states ;
- harmoniser tutoiement/vouvoiement selon le ton existant ;
- rendre les confirmations de suppression explicites ;
- verifier les accents, apostrophes et libelles techniques visibles ;
- ne pas modifier les textes metier qui viennent de la base de donnees.

Contraintes :

- ne pas changer les routes ou comportements ;
- ne pas modifier les traductions enum sans verifier leur usage ;
- conserver une voix simple, culinaire, premium, pas marketing excessive.

### Vues a checker

- Toutes les vues principales en navigation utilisateur
- Tous les empty states
- Toutes les confirmations de suppression
- Pages admin import/tags/ingredients
- Pages Devise

### Nom de commit court

`copy: polish ux wording`
