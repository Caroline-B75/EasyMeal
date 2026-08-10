# Plan d'améliorations UX/UI & PWA — EasyMeal

> Fichier de pilotage. Chaque section ci-dessous est **une requête = un commit**.
> Copie-colle le bloc « 📋 Demande à Claude Code » dans le chat, une requête à la fois.

## Comment utiliser ce fichier

- **Ordre conseillé** : suivre les lots dans l'ordre (0 → 1 → 2 → 3). Le **Lot 0 (PWA)** et le **Lot 1 (fondations)** conditionnent le reste.
- **Une requête à la fois** : attends la fin d'une requête (et vérifie le résultat) avant de lancer la suivante.
- **Dépendances** : indiquées par `↳ Dépend de :` quand une requête en suppose une autre.
- Chaque requête indique **les vues à vérifier** (fichier + URL) pour contrôler le résultat.

## Règles permanentes rappelées à Claude Code (valables pour TOUTES les requêtes)

Ces contraintes s'appliquent à chaque requête sans avoir à les répéter :

- Respecter `CLAUDE.md` : code propre, DRY, **aucun code mort**, meilleures pratiques Rails/Hotwire/HAML.
- Utiliser les **variables CSS** (`var(--color-*)`, tokens d'espacement/typo) — jamais de couleur/taille en dur sauf justification.
- **Tester avant de déclarer terminé** : lire les logs serveur, tracer les types DB, vérifier les méthodes appelées en vue.
- Ne rien casser des parcours existants ; conserver les classes/`data-*` utilisées par les controllers Stimulus et les Turbo Streams.
- Le projet doit devenir une **PWA** installable et utilisable hors-ligne (objectif produit).

---

# LOT 0 — Rendre la PWA réelle (socle)

> Constat : aujourd'hui la PWA n'est pas fonctionnelle — lien manifest cassé, manifest = scaffold Rails (`theme_color: "red"`), service worker vide et **non enregistré**, aucun offline.

## R0.1 — Corriger et personnaliser le manifest

- **Contexte / fichiers**
  - `app/views/layouts/application.html.haml` (ligne ~12 : `%link{rel: "manifest", href: "/manifest.json"}` — cible cassée)
  - `app/views/pwa/manifest.json.erb` (contenu scaffold à réécrire)
  - `config/routes.rb` (lignes ~63-65 : route `pwa_manifest` = `/manifest`, pas `/manifest.json`)
  - Icônes : `public/icon.png`, `public/icon.svg` (vérifier tailles disponibles)
- **Objectif** : que le manifest soit **réellement chargé** et conforme à la charte, pour rendre l'app installable.
- **📋 Demande à Claude Code**
  ```text
  Corrige et personnalise le manifest PWA d'EasyMeal.
  1. Dans app/views/layouts/application.html.haml, le lien manifest pointe vers "/manifest.json"
     alors que la route sert "/manifest" (config/routes.rb, pwa_manifest_path). Corrige le href
     pour utiliser pwa_manifest_path (ou "/manifest").
  2. Réécris app/views/pwa/manifest.json.erb selon la charte "Slate Craft Premium" :
     - name "EasyMeal", short_name "EasyMeal", lang "fr", dir "ltr"
     - description claire du produit (planification de repas + liste de courses)
     - theme_color et background_color issus de la charte (fond crème #F8F7F4, thème anthracite #1C1917) — PAS "red"
     - display "standalone", start_url "/", scope "/"
     - icons : au minimum 192x192 et 512x512, plus une entrée purpose "maskable" (source dédiée si possible)
     - categories ["food", "lifestyle"]
     - shortcuts : "Menu en cours" et "Liste de courses" (vers les bonnes routes)
  3. Vérifie que les fichiers d'icônes référencés existent réellement dans public/ ; si une taille manque,
     indique-le-moi précisément (je fournirai les images) plutôt que de référencer un fichier absent.
  Respecte les règles permanentes du plan.
  ```
- **Vues à vérifier** : n'importe quelle page → DevTools > Application > Manifest (plus d'erreur, couleurs/icônes correctes) ; bouton « Installer » disponible.
- **Commit** : `pwa: fix and customize web app manifest`
- ✅ **Fait** — Note : `name: "My EasyMeal"` est **voulu** (cohérence avec le domaine myeasymeal.fr), `short_name: "EasyMeal"`.

## R0.1bis — Compléter le manifest (résidus de l'audit)

- **Contexte / fichiers**
  - `app/views/pwa/manifest.json.erb` (audité après R0.1)
  - `public/` (icônes)
- **Objectif** : corriger 3 manques relevés à l'audit du manifest livré en R0.1.
- **📋 Demande à Claude Code**
  ```text
  Complète le manifest PWA (app/views/pwa/manifest.json.erb) suite à l'audit. NE CHANGE PAS name ("My EasyMeal")
  ni short_name ("EasyMeal") : c'est voulu (domaine myeasymeal.fr).
  1. Ajoute le champ "id": "/" (stabilité d'identité de la PWA).
  2. Ajoute une icône purpose "maskable" : sans elle, Android affiche l'icône rétrécie dans un cercle blanc.
     Il faut une variante 512x512 avec ~20 % de marge de sécurité autour du logo (zone safe centrale).
     -> public/icon-512-maskable.png
     Si le fichier n'existe pas dans public/, indique-moi précisément la taille et la marge attendues
     (je fournirai l'image) plutôt que de référencer un fichier absent.
  3. Ajoute des "icons" (96x96) aux deux shortcuts : Chrome les exige pour afficher les raccourcis
     dans le menu long-press. -> easymeal\public\icon-96.png Si ça suffit pas, demande moi.
  Respecte les règles permanentes du plan.
  ```
- **Vues à vérifier** : DevTools > Application > Manifest (id, icône maskable sans warning, shortcuts avec icônes) ; sur Android : icône non letterboxée, raccourcis visibles au long-press.
- **Commit** : `pwa: manifest id, maskable icon and shortcut icons`
- ↳ Dépend de : R0.1

## R0.2 — Enregistrer le service worker + cache app shell + page offline

- **Contexte / fichiers**
  - `app/views/pwa/service-worker.js` (actuellement 100% commenté = inactif)
  - Point d'entrée JS (`app/javascript/application.js` ou `entrypoints`) — **aucun** `navigator.serviceWorker.register` n'existe aujourd'hui
  - `config/routes.rb` (route `pwa_service_worker` = `/service-worker`)
- **Objectif** : un service worker **actif** qui met en cache la coquille de l'app et sert une page de secours hors-ligne.
- **📋 Demande à Claude Code**
  ```text
  Active un service worker fonctionnel pour la PWA EasyMeal.
  1. Enregistre le service worker au chargement (navigator.serviceWorker.register vers pwa_service_worker_path,
     soit "/service-worker") depuis le point d'entrée JS, avec garde de compatibilité.
  2. Réécris app/views/pwa/service-worker.js avec une stratégie de cache versionnée :
     - install : pré-cache de l'app shell (CSS/JS compilés, logo, icônes, une page offline).
     - activate : suppression des anciens caches versionnés.
     - fetch : "network-first" pour les navigations HTML avec repli sur la page offline si le réseau échoue ;
       "cache-first" pour les assets statiques (images, CSS, JS).
     - ne jamais mettre en cache les requêtes non-GET ni les réponses d'erreur.
  3. IMPORTANT — assets digestés : les URLs CSS/JS sont fingerprintées par l'asset pipeline, la liste de
     pré-cache ne peut PAS être codée en dur. Le service worker est une vue Rails : renomme-le en
     service-worker.js.erb et génère les URLs via asset_path pour le pré-cache de l'app shell.
  4. Prévois la stratégie de MISE À JOUR du SW : self.skipWaiting() à l'install + clients.claim() à l'activate
     (sinon les utilisateurs restent bloqués sur d'anciennes versions du CSS/JS en cache). Versionne le nom du
     cache avec le digest des assets pour invalider automatiquement à chaque déploiement.
  5. Crée une page/fragment "offline" sobre et à la charte (message + logo + lien retour).
  Respecte les règles permanentes du plan. Teste : DevTools > Application > Service Workers doit montrer le SW
  "activated", et un rechargement en mode Offline doit afficher la page de secours.
  ```
- **Vues à vérifier** : DevTools > Application > Service Workers (statut _activated_) ; passer en _Offline_ puis recharger `/` → page de secours.
- **Commit** : `pwa: register service worker with offline app shell`
- ↳ Dépend de : R0.1

## R0.3 — Liste de courses utilisable hors-ligne

> ⚠️ **Requête la plus risquée du Lot 0** (CSRF au replay, conflits si la liste est régénérée, Turbo Streams qui
> écrasent l'état local). Garder le **scope minimal** décrit ci-dessous ; si elle s'avère lourde, elle est
> **reportable après le Lot 1** — R0.1/0.2/0.4 suffisent déjà pour une PWA installable et honorable.

- **Contexte / fichiers**
  - `app/views/menus/grocery.html.haml`, `app/views/menus/_grocery_item.html.haml`
  - `app/javascript/controllers/grocery_check_controller.js` (toggle coché — déjà en feedback optimiste)
  - `app/views/pwa/service-worker.js` (R0.2)
- **Objectif** : cocher/décocher un article **sans réseau** (en magasin) et synchroniser au retour de connexion.
- **📋 Demande à Claude Code**
  ```text
  Rends la liste de courses utilisable hors-ligne (usage en magasin). SCOPE MINIMAL, pas d'over-engineering.
  1. Assure-toi que la page /menus/:id/grocery et ses assets sont mis en cache par le service worker.
  2. Dans grocery_check_controller, quand le PATCH de toggle échoue pour cause réseau, conserve l'état coché
     localement (file d'attente simple en localStorage) et applique le changement visuel optimiste.
  3. Rejoue automatiquement la file d'attente au retour en ligne (événement "online") pour synchroniser le serveur :
     - relis le token CSRF depuis la meta du document au moment du replay (pas celui mémorisé hors-ligne) ;
     - ignore silencieusement les 404/422 (item supprimé ou liste régénérée entre-temps) et purge la file.
  4. Affiche un indicateur hors-ligne GLOBAL et discret (petit bandeau "Hors ligne" via un controller Stimulus
     branché sur les événements online/offline) + état "synchronisation en cours" sur la liste quand pertinent.
  Garde le comportement actuel identique quand le réseau est disponible. Respecte les règles permanentes.
  Teste en Offline : cocher des articles, revenir Online, vérifier la synchro.
  ```
- **Vues à vérifier** : `/menus/:id/grocery` en mode _Offline_ (cocher/éditer), puis retour _Online_ (synchro) ; bandeau hors-ligne visible sur toutes les pages.
- **Commit** : `pwa: offline support for grocery list`
- ↳ Dépend de : R0.2

## R0.4 — Meta `<head>` : iOS, safe-area, SEO/Open Graph

- **Contexte / fichiers**
  - `app/views/layouts/application.html.haml` (bloc `%head`)
  - `app/assets/stylesheets/layouts.css`, `global.css` (paddings header / éléments fixes)
- **Objectif** : rendu « app-like » sur iOS, gestion de l'encoche, et meta de partage/SEO (catalogue public).
- **📋 Demande à Claude Code**
  ```text
  Complète les meta du <head> pour la PWA et le partage.
  1. iOS : ajoute apple-mobile-web-app-title "EasyMeal", apple-mobile-web-app-status-bar-style adapté à la charte.
     apple-mobile-web-app-capable est déprécié : ajoute aussi la meta standard mobile-web-app-capable.
     Idéalement, l'apple-touch-icon doit être un PNG 180x180 SANS transparence (fond plein #F8F7F4) —
     si le fichier n'existe pas dans public/, demande-le-moi plutôt que de référencer un fichier absent.
  2. Ajoute la meta theme-color (#1C1917, cohérente avec le manifest) — elle colore l'UI du navigateur
     hors app installée.
  3. Ajoute viewport-fit=cover au meta viewport, et applique les env(safe-area-inset-*) en padding sur le header
     fixe, le contenu principal et les éléments fixes (bouton flottant filtres, formulaire d'ajout de course).
  4. SEO/partage : ajoute une meta description par défaut (surchargée par page si utile) et les balises Open Graph
     de base (og:title, og:description, og:type, og:image avec le logo/une photo).
  Respecte les règles permanentes. Vérifie qu'il n'y a pas de régression d'affichage du header.
  ```
- **Vues à vérifier** : `/` (source HTML : meta présentes) ; sur mobile avec encoche, header non masqué ; aperçu de partage (OG).
- **Commit** : `pwa: head meta for ios, safe-area and open graph`

## R0.5 — Audit Lighthouse (filet de sécurité du Lot 0)

- **Contexte / fichiers**
  - Toute l'app (audit transversal après R0.1 → R0.4)
- **Objectif** : valider objectivement l'installabilité PWA, la performance et l'accessibilité de base avant d'attaquer le Lot 1.
- **📋 Demande à Claude Code**
  ```text
  Je vais lancer un audit Lighthouse (PWA / Performance / Accessibility / Best Practices) sur les pages clés
  (/, /recipes, /recipes/:id, /menus/:id, /menus/:id/grocery) et te coller les résultats.
  Analyse chaque point remonté, classe-les par impact/effort, et corrige ceux qui relèvent du Lot 0
  (installabilité, manifest, service worker, meta). Liste ceux qui seront couverts par les requêtes
  suivantes du plan (typo, contrastes, ARIA...) sans les corriger maintenant, pour éviter les doublons.
  Respecte les règles permanentes.
  ```
- **Vues à vérifier** : rapport Lighthouse : installabilité PWA verte, pas de régression de score.
- **Commit** : `pwa: fix lighthouse audit findings`
- ↳ Dépend de : R0.1 → R0.4
- ✅ **Fait — Lot 0 validé, aucun correctif requis.** Audit des 5 pages clés (Chrome navigation privée) :
  Best Practices **100** et SEO **100** partout, installabilité PWA verte, meta OK → rien à corriger côté Lot 0 (pas de commit).
  Le faible score Performances (30 avec extensions → 56-68 en navigation privée) vient de gros assets statiques
  (`kitchen_2.jpg` 1,4 Mo, `photo_par_defaut_recette.png` 2,2 Mo) + artefacts du mode développement (CSS non
  compressé/minifié, HTTP/1.1), non des sujets du Lot 0. Points reportés :
  poids images (assets statiques + dimensionnement Cloudinary) → **R3.7 (pt 0)** ; `lang`, nom accessible du menu,
  contrastes, ordre des titres, id dupliqués → **R1.3 (pts 1, 4, 5, 8, 9)** ; tailles de police contenu → **R1.2** ;
  `font-display` → **R1.1**.

---

# LOT 1 — Fondations design system (fort levier, toutes les vues)

## R1.1 — Unifier la police de base

- **Contexte / fichiers**
  - `app/assets/stylesheets/global.css` (**deux blocs `body`** : l.~10 avec `'Inter'`, l.~145 sans → Inter écrasée ; Inter jamais importée)
  - `app/views/layouts/application.html.haml` (`%head`)
  - `app/assets/stylesheets/variables.css`
- **Objectif** : une police cohérente **réellement appliquée** sur toute l'app.
- **📋 Demande à Claude Code**
  ```text
  Corrige la typographie de base. Actuellement global.css déclare deux blocs body avec des font-family
  différentes (le second, sans Inter, l'emporte) et Inter n'est importée nulle part.
  Décision : self-héberger Inter via l'asset pipeline (woff2) OU assumer une pile système. Choisis la plus
  robuste et explique brièvement ton choix.
  - Fusionne les deux blocs body en un seul, avec une seule font-family.
  - Si Inter : ajoute @font-face (woff2 local), précharge la graisse principale, et une pile de repli système.
  - Assure -webkit-font-smoothing / antialiasing une seule fois.
  Respecte les règles permanentes. Aucun doublon de règle body ne doit subsister.
  ```
- **Vues à vérifier** : toutes (rendu du texte) — comparer avant/après, aucune FOUT gênante.
- **Commit** : `style: unify base font family`

## R1.2 — Refondre l'échelle typographique et remonter le texte de contenu

- **Contexte / fichiers**
  - `app/assets/stylesheets/variables.css` (`--font-size-sm` == `--font-size-base` == 1rem, `xs` 14px incohérent)
  - `app/assets/stylesheets/recipes.css` (préfixe `rs-` : tailles en dur 9/10/11/12/13px)
  - `app/assets/stylesheets/menus.css` (préfixes `mc- / mi- / mn-`)
- **Objectif** : lisibilité (contenu ≥ 15-16px) et cohérence via tokens.
- **📋 Demande à Claude Code**
  ```text
  Refonds l'échelle typographique et applique-la.
  1. Dans variables.css, définis une échelle cohérente et non redondante
     (ex. xs 12 / sm 14 / base 16 / lg 18 / xl 20 / 2xl 24 / 3xl 30 / 4xl 36) — plus de doublon sm/base.
  2. Remplace les tailles de police en dur (9-13px) des fiches recette (rs-) et des menus (mc-/mi-/mn-)
     par les tokens. Le texte de CONTENU (étapes de préparation, ingrédients, avis, noms) doit être >= 15px ;
     les labels secondaires >= 12px. Ne descends jamais sous 12px.
  Vérifie qu'aucune régression de mise en page n'apparaît sur la fiche recette et les menus.
  Respecte les règles permanentes.
  ```
- **Vues à vérifier** : `/recipes/:id` (étapes, ingrédients, avis), `/menus/:id`, `/menus/:id/grocery`.
- **Commit** : `style: rework typographic scale and sizes`

## R1.3 — Accessibilité de base

- **Contexte / fichiers**
  - `app/views/layouts/application.html.haml` (`%html` **sans `lang`**)
  - `app/assets/stylesheets/global.css` (focus, contrastes)
  - Accordéons/menus : `grocery_accordion_controller.js`, `recipe_filter_controller.js`, `menu_controller.js` (dropdown)
- **Objectif** : socle accessibilité (langue, focus visible, contraste, ARIA).
- **📋 Demande à Claude Code**
  ```text
  Pose les bases d'accessibilité.
  1. Ajoute lang="fr" sur l'élément %html du layout.
  2. Ajoute un skip-link "Aller au contenu" en premier élément focusable du body (visible au focus uniquement),
     pointant vers le conteneur principal (ajoute un id/landmark main si nécessaire).
  3. Ajoute une règle globale :focus-visible cohérente (outline 2px var(--color-primary), offset 2px)
     sur les éléments interactifs (a, button, input, select, [role="button"], chips de filtre, cartes cliquables).
  4. Corrige les textes à faible contraste : n'utilise plus --color-ink-4 pour du texte porteur d'information
     (bascule vers ink-3/ink-2) ; vérifie les paires couleur/taille contre WCAG AA.
  5. Ajoute aria-expanded (et aria-controls) sur les déclencheurs d'accordéons (rayons de courses, filtres)
     et sur le menu utilisateur (dropdown), en synchronisant l'attribut dans les controllers Stimulus concernés.
  6. Ajoute aria-live="polite" sur le conteneur #flash (crucial : il est mis à jour dynamiquement par les
     Turbo Streams, les lecteurs d'écran doivent annoncer les messages).
  7. Généralise la règle prefers-reduced-motion (aujourd'hui uniquement dans authentication.css) en une règle
     globale dans global.css qui neutralise animations et transitions décoratives.
  8. Corrige l'ordre des titres (audit Lighthouse R0.5) : sauts de niveau détectés sur h3.hero-step-title
     (home/_vitrine.html.haml) et h3.recipe-card-title (recipes/index) utilisés sans h2 parent. Rétablis une
     hiérarchie séquentielle (pas de saut de niveau) sans casser le style visuel.
  9. Corrige les id HTML dupliqués sur la liste de courses (audit Lighthouse R0.5) : input#grocery_item_quantity_base
     apparaît plusieurs fois (les id doivent être uniques). Rends-les uniques (ex. suffixe par item) sans casser
     grocery_edit_qty_controller ni les Turbo Streams.
  Respecte les règles permanentes. Teste la navigation entièrement au clavier.
  ```
- **Vues à vérifier** : navigation clavier sur `/recipes`, `/menus/:id/grocery` (accordéons), header (dropdown) ; contrastes sur `/recipes/:id`.
  Explique moi très clairement, pas à pas, ce que je dois vérifier pour valider que tout est correct.
- **Commit** : `a11y: language, focus states, contrast, aria` (ne commite pas avant validation complète )

## R1.3b — Bug : la page de connexion « mouline » et ne s'affiche pas depuis l'accueil

> ✅ **FAIT** — `stylesheet_link_tag "authentication"` redondant retiré des vues Devise
> (authentication.css est déjà dans le bundle global). Connexion depuis l'accueil validée.

- **Contexte / fichiers**
  - Symptôme : déconnecté, sur `/` (accueil vitrine), un clic sur **« Se connecter »**
    (header : `app/views/layouts/application.html.haml`, lien `new_user_session_path`)
    déclenche un spinner Turbo qui tourne sans jamais afficher la page.
    En revanche, en passant par **« S'inscrire »** puis **« Me connecter »**
    (`devise/shared/_links.html.erb`), la page de login s'affiche normalement.
  - `app/views/devise/sessions/new.html.erb` et `app/views/devise/registrations/new.html.erb`
    chargent tous deux, en `content_for :head`, `stylesheet_link_tag "authentication", "data-turbo-track": "reload"`.
    L'accueil, lui, ne charge PAS cette feuille.
  - `app/views/pwa/service-worker.js.erb` : les navigations HTML sont en _network-first_
    avec `fetch(request, { cache: "no-store" })`.
- **Hypothèse principale** : quand Turbo Drive navigue de l'accueil (sans `authentication.css`)
  vers la page de login (avec un asset `data-turbo-track="reload"` absent de la page courante),
  Turbo détecte un changement d'asset suivi et force un **rechargement complet** de la page.
  Ce rechargement complet, combiné à l'interception du **service worker** (et/ou à la première
  compilation de `authentication.css` en dev), semble ne jamais aboutir. Depuis la page d'inscription,
  l'asset suivi est déjà présent → visite Turbo normale, sans rechargement → pas de blocage.
- **📋 Demande à Claude Code**
  ```text
  Corrige le blocage de la page de connexion atteinte depuis l'accueil (déconnecté).
  1. Reproduis et confirme la cause : ouvre l'onglet Réseau + Console, va sur / (déconnecté),
     clique « Se connecter ». Note si Turbo fait un rechargement complet (data-turbo-track),
     si le service worker intercepte la requête /users/sign_in, et si celle-ci reste "pending".
  2. Vérifie l'hypothèse du "data-turbo-track reload" : compare le <head> de l'accueil et des
     pages Devise. La feuille authentication.css n'est présente que sur les pages Devise.
  3. Applique la correction la plus propre et robuste (choisir selon le diagnostic) :
     - soit charger authentication.css de façon cohérente pour éviter le mismatch d'asset suivi
       (ex. l'inclure dans le bundle application, ou la précharger globalement), OU retirer
       data-turbo-track="reload" si non nécessaire ;
     - soit, si le service worker est en cause, s'assurer que les navigations HTML ne restent
       jamais bloquées (timeout réseau + repli propre), sans casser le mode hors-ligne (R0.x).
  4. Ne dégrade pas le fonctionnement hors-ligne existant ni le préchargement de l'app shell.
  Respecte les règles permanentes. Teste : /  →  « Se connecter »  →  la page login s'affiche
  immédiatement ; puis register → « Me connecter » fonctionne toujours ; puis connexion réussie.
  ```
- **Vues à vérifier** : `/` (déconnecté) → « Se connecter » ; `/users/sign_up` → « Me connecter » ;
  soumission du formulaire de login ; comportement hors-ligne inchangé (`/menus/:id/grocery`).
- **Commit** : `fix: unblock sign-in navigation from home`

## R1.3c — Finaliser les contrastes WCAG AA (Lighthouse 96 → 100) + survol des boutons-liens

> ✅ **FAIT** — (1) opacité retirée des items cochés ; (2) titres/compteurs de rayon en `ink`
> (couleur du rayon conservée en décor : liseré + pastille) ; (3) `.rs-btn-accent` texte en `ink`
> (base + hover) ; (4) règle globale `a:hover` restreinte pour ne plus toucher les `.btn*`.
> À revalider au Lighthouse (viser 100). La demande ci-dessous est conservée pour référence.

- **Contexte** : après R1.3, Lighthouse Accessibilité = **100** sur l'accueil mais **96** sur
  `/menus/:id/grocery` et `/recipes/:id`. Déjà corrigé dans R1.3 : `--color-ink-3` assombri
  (#78716C → #6B645E, passe AA sur fonds clairs) et `.rs-meta-label` (gris clair sur hero sombre).
  Restent des cas **à trancher car ils touchent le design** :
- **📋 Demande à Claude Code**
  ```text
  Objectif : 100 en Accessibilité sur /menus/:id/grocery et /recipes/:id, sans dégrader le design.
  1. Items de courses cochés — grocery_items.css `.grocery-item--checked { opacity: 0.5 }` :
     l'opacité 0.5 s'applique à toute la ligne et fait chuter le contraste du nom et de la
     quantité sous 4.5:1. Remplace la mise en sourdine par des COULEURS explicites conformes
     (ex. retirer l'opacité du conteneur ; garder le barré sur le nom + couleur ink-3 ; ne
     dimmer que la case à cocher/les décorations non textuelles). La coche + le barré doivent
     rester des indices « fait » clairs.
  2. Couleurs de rayon comme TEXTE — `.grocery-section-title` et `.grocery-section-count`
     utilisent `var(--section-color)` (≈ #9E9E9E, #C49A27, #6A9BB5, #5A8A5B…). En texte sur
     blanc/tuile, ~15 des 20 couleurs échouent AA. Deux options au choix : (a) assombrir la
     palette --section-color pour qu'elle passe AA en texte ≥ 4.5:1, ou (b) garder les couleurs
     uniquement en décor (liseré/pastille) et mettre le TEXTE des titres/compteurs en
     var(--color-ink) / var(--color-ink-2). Recommandation : option (b), plus robuste.
  3. Bouton accent — recipes.css `.rs-btn-accent` : texte accent-text (#92400E) sur accent
     (#FBBF24) = 4,24:1 (< 4.5). Assombris le texte (ex. var(--color-ink) / #7A3D00) ou éclaircis
     le fond, pour atteindre ≥ 4.5:1 en gardant l'esprit ambre.
  4. Survol des boutons-liens (contraste au hover) : la règle globale
     global.css `a:hover { color: var(--color-ink); text-decoration: underline }` s'applique à
     TOUT <a>, y compris les <a> stylés en boutons. Les boutons foncés/colorés qui NE redéclarent
     PAS de couleur au :hover affichent alors un texte foncé (et un soulignement) au survol.
     - Déjà protégés (redéclarent color au :hover) : .btn-primary (components.css), .btn-hero,
       .btn-signup, .rs-btn-accent. Déjà corrigé : .skip-link.
     - À auditer et corriger : tous les autres <a> foncés/colorés — notamment .mi-btn-* (menus),
       .btn-danger, .btn-link, liens de nav sur fond foncé — vérifier qu'ils gardent une couleur
       lisible ET text-decoration:none au survol.
     - Correctif systémique recommandé (à faire dans R1.5) : restreindre la règle globale
       a:hover pour qu'elle n'atteigne pas les .btn* (ex. `a:not([class*="btn"]):hover`), ou
       ajouter une base `.btn:hover { color: inherit; text-decoration: none }`.
  Respecte les règles permanentes. Revalide avec Lighthouse (viser 100) et au survol souris.
  ```
- **Vues à vérifier** : `/menus/:id/grocery` (rayons, items cochés), `/recipes/:id` (hero, bouton
  « Ajouter à mon menu », sections, avis) ; survol de tous les boutons-liens foncés.
- **Commit** : `a11y: finish AA contrast + button hover legibility`

## R1.4 — Dédupliquer le CSS, corriger les largeurs fixes et les bordures

- **Contexte / fichiers**
  - `.form-row` défini 3× (`recipes.css` flex, `components.css` grid, `authentication.css` grid) ; `.form-label` 18px (`components.css`) vs 14px (`authentication.css`)
  - Largeurs : `ingredients.css:12` `width:50%`, `menus.css:15` `width:50%`, `recipes.css:1702` `min-width:50%`
  - Bordures `0.5px` disséminées (~100 occurrences, rendu non fiable non-retina)
  - Couleurs **en dur hors variables** dans `menus.css` (`#44403C`, `#3C3836`, `#292524`, `#FECACA`, `#3C1515`…) — violation de la règle « variables CSS obligatoires »
  - Breakpoints incohérents : majorité `max-width: 767px`, mais `grocery_items.css`, `menus.css` (l.1164) et `select2_custom.css` coupent à `768px` (+ 600/640/360/374 dispersés)
- **Objectif** : supprimer les conflits, rendre les pages fluides sur grand écran, fiabiliser les bordures.
- **📋 Demande à Claude Code**
  ```text
  Nettoie et fiabilise le CSS structurel.
  1. Déduplique .form-row et .form-label : une seule définition canonique (dans components.css), supprime
     les variantes conflictuelles d'authentication.css et recipes.css (ou fais-les converger sans !important).
  2. Remplace les largeurs fixes qui étranglent le contenu : ingredients.css (width:50%) et menus.css (width:50%)
     et recipes.css (min-width:50%) → conteneurs fluides "width:100%; max-width: ~1100px; margin auto"
     (adapte la valeur à chaque écran).
  3. Remplace les ~100 bordures 0.5px par 1px (rendu fiable) en conservant l'aspect fin via la couleur de bordure.
     Fais-le en DRY : introduis un token --border-width: 1px dans variables.css (voire un raccourci
     --border-thin: 1px solid var(--color-border)) plutôt que 100 valeurs en dur.
  4. Remplace les couleurs codées en dur de menus.css (#44403C, #3C3836, #292524, #FECACA, #3C1515...)
     par les variables de la charte (ou de nouvelles variables si un ton manque — les déclarer dans variables.css).
  5. Standardise les breakpoints : mobile max-width 767px / tablette 768-1024px / desktop min-width 1025px partout.
     Corrige les media queries à 768px de grocery_items.css, menus.css et select2_custom.css qui chevauchent
     la plage tablette à exactement 768px.
  Vérifie l'absence de régression sur formulaires, liste ingrédients et liste des menus en grand écran.
  Respecte les règles permanentes.
  ```
- **Vues à vérifier** : `/ingredients` et `/menus` en large desktop (largeur exploitée) ; formulaires recette/ingrédient/auth (labels cohérents).
- **Commit** : `style: dedupe form rules, fix fixed widths and borders`

## R1.5 — Unifier le système de boutons et la sémantique couleur

- **Contexte / fichiers**
  - `components.css` (`.btn*`), `home.css` (`.btn-hero`), `recipes.css` (`.rs-btn-accent`, `.btn-accent`), `menus.css` (`.mc-/.mi-/.mn-` boutons), `tags.css` (save = **ambre**, l.155), `layouts.css` (état actif nav = ambre)
- **Objectif** : un seul système de boutons + une sémantique couleur claire et cohérente.
- **📋 Demande à Claude Code**
  ```text
  Unifie les boutons et clarifie la sémantique couleur.
  1. Consolide tout autour d'un système .btn + variantes (--primary, --secondary, --accent, --danger, --ghost)
     et des tailles (--sm, --lg). Migre les boutons spécifiques (btn-hero, rs-btn-accent, mc-/mi-/mn-*, draft-*)
     vers ce système ; supprime les doublons devenus inutiles.
  2. Fixe la sémantique : action PRINCIPALE = une seule couleur cohérente dans toute l'app (anthracite --color-primary) ;
     ambre = accent réservé à un rôle unique et cohérent (étoiles/saison + éventuellement 1 CTA "accent" assumé) ;
     destructif = rouge (à CONSERVER pour les suppressions) ; secondaire = neutre.
  3. En conséquence : corrige le bouton "save" ambre de tags.css pour respecter cette sémantique.
     Laisse l'état actif de navigation en accent seulement s'il reste le seul usage "accent" de la nav.
  Respecte les règles permanentes. Vérifie visuellement les CTA sur toutes les vues clés.
  ```
- **Vues à vérifier** : `/` (hero), `/recipes/:id` (Ajouter à mon menu), `/menus/new` (Générer), `/tags` (save), `/menus/:id/grocery`.
- **Commit** : `style: consolidate button system and color semantics`

## R1.6 — Remplacer les emojis d'interface par des icônes SVG

- **Contexte / fichiers**
  - `recipes/index.html.haml` (🔍 ♥ 🌿 🍳), `recipe_imports/new.html.haml` (🔗 📸 📷), `menus/index.html.haml` (🍽), divers `✚ ✕ ×`
  - Helper `svg_icon` / `inline_svg` (`app/helpers/application_helper.rb`) + jeu d'icônes existant
- **Objectif** : iconographie unifiée, premium et accessible (les emojis rendent différemment selon l'OS).
- **📋 Demande à Claude Code**
  ```text
  Remplace tous les emojis d'INTERFACE par le système d'icônes SVG (helper svg_icon/inline_svg).
  Cibles connues : catalogue recettes (loupe, cœur favoris, feuille "de saison", icône empty state),
  import IA (onglets lien/photo, appareil photo), empty states menus, boutons +/✕/× .
  - Conserve/ajoute des aria-label explicites sur les boutons icône.
  - Si une icône manque au jeu SVG, ajoute-la proprement au set existant (même convention de nommage/couleur).
  - Ne touche PAS aux emojis qui sont du contenu utilisateur, seulement au chrome d'interface.
  Respecte les règles permanentes.
  ```
- **Vues à vérifier** : `/recipes` (filtres, empty state), `/recipe_imports/new`, `/menus` (empty state).
- **Commit** : `style: replace UI emojis with SVG icons`

## R1.7 — Convertir les vues Devise ERB → HAML

- **Contexte / fichiers**
  - `app/views/devise/sessions/new.html.erb`, `registrations/new.html.erb`, `passwords/new.html.erb`, `shared/_links.html.erb`
  - Convention `CLAUDE.md` : HAML partout
- **Objectif** : cohérence et maintenabilité (respect de la convention HAML du projet).
- **📋 Demande à Claude Code**
  ```text
  Convertis les vues Devise de ERB vers HAML sans changement fonctionnel :
  sessions/new, registrations/new, passwords/new, shared/_links.
  - Markup, classes CSS et structure identiques (mêmes classes .auth-*, .form-*).
  - Supprime les fichiers .erb correspondants une fois les .haml en place.
  - Vérifie que connexion, inscription et mot de passe oublié fonctionnent toujours.
  Respecte les règles permanentes.
  ```
- **Vues à vérifier** : `/users/sign_in`, `/users/sign_up`, `/users/password/new` (rendu identique, formulaires fonctionnels).
- **Commit** : `refactor: convert devise views to haml`

---

# LOT 2 — Parcours quotidiens (impact utilisateur)

## R2.1 — Accueil connecté = mini tableau de bord

- **Contexte / fichiers**
  - `app/views/home/index.html.haml`, `_dashboard.html.haml`, `_dashboard_active.html.haml`, `_dashboard_draft.html.haml`, `home.css`
  - Helpers : `current_active_menu` ; modèles `Menu` / `GroceryItem` (progression)
- **Objectif** : transformer la rangée de CTA en accueil **opérationnel** (l'app s'ouvre sur l'essentiel).
- **📋 Demande à Claude Code**
  ```text
  Transforme l'accueil connecté en mini tableau de bord opérationnel (garde la vitrine pour les visiteurs).
  Selon l'état de l'utilisateur, affiche une carte de synthèse :
  - Menu actif : nom, nombre de repas, éventuel "prochain repas", et progression de la liste de courses
    (X/Y articles cochés, barre de progression).
  - Brouillon en cours : rappel "à valider" + reprise.
  - Aucun menu : incitation claire à en créer un.
  Fournis UN bouton principal contextuel (le plus utile selon l'état) + actions secondaires discrètes.
  Réutilise les helpers existants ; ajoute au besoin une méthode de progression courses sur le modèle
  (vérifie les types en DB). Respecte la charte et les règles permanentes.
  ```
- **Vues à vérifier** : `/` connecté dans les 3 états (avec menu actif, avec brouillon, sans menu).
- **Commit** : `feat: actionable connected home dashboard`

## R2.2 — Liste de courses : barre d'actions et ergonomie

> ✅ **Fait partiellement** — la barre d'actions du point 1 (« Tout cocher / Tout décocher »,
> « Masquer les cochés », « Régénérer ») a été **volontairement écartée** : ne pas la (re)proposer.

- **Contexte / fichiers**
  - `menus/grocery.html.haml`, `_grocery_list.html.haml`, `_grocery_section.html.haml`, `_grocery_item.html.haml`
  - Controllers : `grocery_sections_controller.js`, `grocery_check_controller.js`, `grocery_edit_qty_controller.js` ; `grocery_items.css`
  - Route existante : `regenerate_grocery` (Turbo Stream)
- **Objectif** : liste efficace en magasin (progression, actions groupées, quantité éditable découvrable).
- **📋 Demande à Claude Code**
  ```text
  Améliore la page liste de courses (/menus/:id/grocery).
  1. Ajoute une barre supérieure : "X articles restants", "Tout cocher / Tout décocher", "Masquer les articles cochés",
     "Régénérer" (route regenerate_grocery existante) et "Retour au menu".
  2. Rends l'édition de quantité DÉCOUVRABLE : petite icône crayon ou état hover/focus explicite sur la quantité ;
     agrandis la zone tactile sur mobile.
  3. Transforme le formulaire d'ajout manuel en ligne compacte dépliable ("+ Ajouter un article") pour gagner de la place,
     surtout sur mobile. Évite de coder les unités en dur dans la vue si elles existent côté modèle (mutualise).
  Conserve les Turbo Streams et le feedback optimiste. Respecte les règles permanentes.
  ```
- **Vues à vérifier** : `/menus/:id/grocery` (desktop + mobile) : compteur, tout cocher, masquer cochés, régénérer, ajout dépliable.
- **Commit** : `feat: grocery list action bar and usability`

## R2.3 — Mutualiser les paramètres de menu (génération / régénération)

- **Contexte / fichiers**
  - `menus/_form_generate.html.haml` (icônes SVG régime + **slider** personnes, régimes **codés en dur**, pas de résumé)
  - `menus/_form_regenerate.html.haml` (pas d'icônes + **stepper +/−** personnes + **barre résumé**, régimes **bouclés**)
  - `menu_generate_controller.js`, `menus.css`
- **Objectif** : une seule UI de paramètres pour une tâche mentalement identique (fin de l'effet « assemblé par morceaux » + DRY).
- **📋 Demande à Claude Code**
  ```text
  Mutualise les paramètres de menu en UN seul partial partagé par la génération et la régénération.
  Aujourd'hui _form_generate (icônes de régime + slider personnes, régimes codés en dur, sans résumé) et
  _form_regenerate (sans icônes + stepper +/−, avec barre résumé) divergent pour une tâche identique.
  1. Crée un partial unique de paramètres : grille de régimes AVEC icônes, contrôle "personnes", "repas",
     "nom optionnel" et la barre résumé — présents dans les DEUX parcours.
  2. Boucle les régimes dynamiquement (Menu.diets) pour ne rien coder en dur (DRY : un nouveau régime ne doit rien casser).
  3. Choisis UN seul contrôle "personnes" (slider ou stepper) et applique-le partout.
  Les deux formulaires ne diffèrent que par l'URL/le libellé du bouton et le turbo_confirm de régénération.
  Respecte les règles permanentes ; teste génération ET régénération.
  ```
- **Vues à vérifier** : `/menus/new` et la régénération depuis un brouillon (`/menus/:id`) — même UI, deux comportements.
- **Commit** : `refactor: unify menu params form (generate/regenerate)`
- ↳ Dépend de : R1.6 (icônes SVG)

## R2.4 — Fiche recette : ingrédients sticky, CTA persistant, bouton Partager

- **Contexte / fichiers**
  - `recipes/show.html.haml` (bouton « Partager » l.~59 **sans action** ; kicker + badges **dupliquent** régime/tags)
  - `recipes.css` (préfixe `rs-`) ; possibilité d'un nouveau `share_controller.js`
- **Objectif** : confort de lecture (ingrédients toujours visibles) + action d'ajout toujours accessible + partage fonctionnel.
- **📋 Demande à Claude Code**
  ```text
  Améliore la fiche recette (/recipes/:id).
  1. Rends la colonne INGRÉDIENTS sticky sur desktop (elle reste visible pendant la lecture des étapes).
  2. Sur mobile, rends le CTA "Ajouter à mon menu" persistant (barre sticky en bas), sans masquer le contenu.
  3. Câble le bouton "Partager" : Web Share API via un petit controller Stimulus, avec repli "copier le lien"
     si l'API n'est pas disponible. (Si tu juges préférable, propose de le retirer plutôt que de le laisser inerte.)
  4. Supprime la duplication régime/tags entre le kicker et les badges (garder un seul emplacement).
  Respecte la charte et les règles permanentes.
  ```
- **Vues à vérifier** : `/recipes/:id` desktop (ingrédients sticky) et mobile (CTA sticky, partage).
- **Commit** : `feat: recipe page sticky ingredients and share`

## R2.5 — Réorganisation de menu accessible + validation sticky

- **Contexte / fichiers**
  - `menus/_draft_view.html.haml`, `_menu_recipe_card.html.haml` (drag & drop only)
  - `menu_customize_controller.js`, `menus.css`
- **Objectif** : réorganiser sans drag (clavier/mobile) et garder la validation visible.
- **📋 Demande à Claude Code**
  ```text
  Rends la personnalisation de menu (brouillon) accessible.
  1. Ajoute une alternative au drag & drop : boutons "monter/descendre" (ou menu d'ordre) sur chaque carte repas,
     utilisables au clavier et sur mobile, réutilisant la route de réordonnancement existante.
  2. Rends le CTA "Valider et générer la liste de courses" sticky en bas quand le menu contient au moins un repas.
  3. Rends les actions de carte (remplacer / personnes / supprimer) explicites : libellés accessibles / tooltips
     accessibles au focus, pas seulement au hover.
  Conserve le drag & drop existant. Respecte les règles permanentes.
  ```
- **Vues à vérifier** : `/menus/:id` (brouillon) : réordonner au clavier, valider sticky, actions lisibles.
- **Commit** : `a11y: menu reorder controls and sticky validate`

---

# LOT 3 — Polish & admin

## R3.1 — Alléger le formulaire d'inscription

- **Contexte / fichiers**
  - `app/views/devise/registrations/new.haml` (après R1.7) — champ **`gender` obligatoire** binaire ; `username` obligatoire **en plus** de l'email
  - Modèle `User` (validations `gender` / `username`) ; `authentication.css`
- **Objectif** : réduire la friction et l'exclusion à l'inscription (aucun champ inutile obligatoire).
- **📋 Demande à Claude Code**

  ```text
  Allège l'inscription (/users/sign_up).
  1. Retire le champ "genre" optionnel s'il n'est pas utilisé par le produit — VÉRIFIE d'abord les validations du modèle User et les usages. S'il est utilisé quelque part, indique le moi.
  2. Évalue la nécessité de "username" :
     -> retire le champ username et sa validation obligatoire mais vérifie qu'on ne l'utilise pas quelque part (profil, URL, etc.) ; sinon, remplace le par le prénom.
   3. On peut se logger avec l'email + mot de passe, pas besoin d'un pseudo public.

  Adapte le modèle/les validations en conséquence (teste que l'inscription passe). Respecte les règles permanentes.
  ```

- **Vues à vérifier** : `/users/sign_up` (formulaire allégé, inscription fonctionnelle).
- **Commit** : `ux: streamline sign-up form`
- ↳ Dépend de : R1.7

## R3.2 — Catalogue recettes : cartes et filtres

- **Contexte / fichiers**
  - `recipes/index.html.haml`, `recipes.css` (sidebar filtres dense ; métas de carte)
- **Objectif** : cartes plus lisibles et filtres moins écrasants.
- **📋 Demande à Claude Code**
  ```text
  Améliore le catalogue recettes (/recipes).
  1. Cartes : hiérarchise les métas (temps total en premier, régime en badge, note lisible) ; n'affiche le badge
     "de saison" que s'il est pertinent.
  2. Filtres (sidebar) : garde les filtres principaux visibles, replie les TAGS par type en accordéons,
     rends les chips de filtres actifs plus lisibles et le bouton "Effacer/Réinitialiser" plus évident.
  3. Aère la densité de la sidebar desktop (tailles trop petites).
  Conserve l'auto-submit et le Turbo Frame de résultats. Respecte les règles permanentes.
  ```
- **Vues à vérifier** : `/recipes` (desktop + mobile) : cartes, accordéons de tags, reset visible.
- **Commit** : `ux: recipe cards and filter sidebar polish`

## R3.2bis — Cycle de vie du menu : « Menu actif » modifiable + réconciliation intelligente de la liste de courses

> ⚠️ **Requête délicate** (transition d'état + réconciliation de données cochées). Bien lire le contexte :
> aujourd'hui un menu validé (`status: :active`) est en **lecture seule totale** — aucun chemin de retour.
> Scénario réel bloquant : menu validé lundi, des invités arrivent jeudi → impossible d'échanger un repas.
> La solution retenue : **repasser le menu actif en brouillon** (bouton « Modifier ce menu »), puis à la
> revalidation, **réconcilier** la liste de courses au lieu de la détruire (option « C-simple » :
> les coches sont conservées sauf si la quantité a augmenté, avec un badge explicatif).

- **Contexte / fichiers**
  - `app/models/menu.rb` : `activate!` appelle `Groceries::BuildForMenuService` ; `reactivate!` ; enum `status { draft: 0, active: 1, archived: 2 }`
  - `app/services/groceries/build_for_menu_service.rb` : fait actuellement `grocery_items.generated.destroy_all` puis recrée tout → **toutes les coches sont perdues** (les items `:manual` sont déjà préservés, ne pas y toucher)
  - `app/controllers/menus_controller.rb` (+ `config/routes.rb`, `app/policies/menu_policy.rb`) : actions member existantes `activate` / `reactivate` (pattern `transition_menu` à réutiliser)
  - `app/controllers/menus_controller.rb#classify_menus` : `@draft = @menus.find(&:status_draft?)` → ne montre QUE le brouillon le plus récent (les autres deviennent invisibles)
  - Libellés « En cours » / « Menu en cours » restants : `menus/index.html.haml` (badge), `menus/show.html.haml` (chip), `layouts/application.html.haml` (nav ×2), `pwa/manifest.json.erb` (shortcut) — `menus_helper.rb#menu_status_label` et le dashboard accueil disent déjà « Actif »
  - Vues : `app/views/menus/show.html.haml` (chip « En cours »), `index.html.haml` (badge `mi-badge-active` « En cours »), `_active_view.html.haml` (lecture seule), `_draft_view.html.haml` (turbo*confirm de validation), `_grocery_item.html.haml` (ligne d'article, turbo_frame `grocery_item*<id>`)
  - `app/models/grocery_item.rb` : `quantity_display` (l.~111), enum `source { generated, manual }`, colonne `checked` (boolean), `quantity_base` (decimal 10,3)
  - `app/controllers/grocery_items_controller.rb#update` : PATCH utilisé pour cocher/décocher ET pour éditer la quantité
  - `db/schema.rb` : table `grocery_items` (migration à créer)
- **Objectif** : offrir un chemin de retour sûr depuis le menu actif, sans jamais perdre le travail de courses déjà fait, et clarifier le vocabulaire du cycle de vie.
- **📋 Demande à Claude Code**

  ```text
  Rends le menu actif modifiable via un retour en brouillon, avec réconciliation intelligente de la liste
  de courses à la revalidation. Requête en 6 parties, à implémenter ENSEMBLE (un seul commit).

  PARTIE 1 — Vocabulaire « Menu actif »
  Remplace le libellé « En cours » (ambigu : peut vouloir dire « en cours de composition ») par « Actif » /
  « Menu actif ». Occurrences VÉRIFIÉES à corriger :
  - menus/index.html.haml : badge .mi-badge-active « En cours » → « Actif »
  - menus/show.html.haml (l.~38) : chip .mc-chip-active « En cours » → « Actif »
  - layouts/application.html.haml (l.~73 et l.~106) : liens de navigation « Menu en cours » → « Menu actif »
  - pwa/manifest.json.erb : shortcut "name": "Menu en cours" → "Menu actif"
  - menus.css (l.~980) : mets à jour le commentaire /* Chip "En cours" ... */
  NE touche PAS : menus_helper.rb#menu_status_label et home/_dashboard_active.html.haml (disent DÉJÀ
  « Actif »), le label de section « Menu actif » de l'index, ni les statuts « À valider » (draft) et
  « Terminé »/« Archivé » (archived). Termine par un grep "En cours"/"en cours" sur app/views et
  app/helpers pour vérifier qu'aucun libellé UI du cycle de vie menu ne subsiste (ignore les « en
  cours » génériques : spinners de chargement, commentaires de code, textes d'import).

  PARTIE 2 — Migration
  Ajoute une colonne à grocery_items : previous_quantity_base, decimal precision 10 scale 3, null: true
  (mêmes précision/échelle que quantity_base). Elle mémorise l'ancienne quantité quand une réconciliation
  augmente la quantité d'un article qui était coché — pour afficher le badge (partie 4).

  PARTIE 3 — Réconciliation dans Groceries::BuildForMenuService (cœur de la requête)
  Remplace le « destroy_all + recréation » des items :generated par une réconciliation par ingredient_id,
  dans la transaction existante. Règles EXACTES, pour chaque ingrédient agrégé du menu :
  a) L'item generated existe et la nouvelle quantité est ÉGALE à l'ancienne (comparer les decimals
     arrondis à 3 décimales, pas d'égalité flottante naïve) → ne rien changer (coche conservée),
     et remettre previous_quantity_base à nil s'il était renseigné.
  b) L'item existe et la quantité DIMINUE → mettre à jour quantity_base, CONSERVER checked
     (l'utilisateur a déjà assez acheté), previous_quantity_base := nil.
  c) L'item existe, la quantité AUGMENTE et l'item était COCHÉ → mettre à jour quantity_base,
     passer checked à false, et previous_quantity_base := ancienne quantité (pour le badge).
  d) L'item existe, la quantité AUGMENTE et l'item était DÉCOCHÉ → mettre à jour quantity_base
     seulement, pas de badge (previous_quantity_base reste nil).
  e) L'ingrédient a DISPARU du menu → détruire l'item generated correspondant.
  f) NOUVEL ingrédient → créer l'item comme aujourd'hui (checked: false).
  Dans les cas a-d, rafraîchis aussi name / base_unit / unit_group / category depuis l'ingrédient
  (comme le fait la création actuelle) pour rester cohérent si l'ingrédient a changé.
  Les items source: :manual ne sont JAMAIS touchés (comportement actuel à préserver).
  Charge les items existants en une seule requête indexée par ingredient_id (pas de N+1).
  Le service doit rester idempotent : deux appels consécutifs sans changement de menu ne modifient rien.

  PARTIE 4 — Badge « quantité augmentée » sur la liste de courses
  Dans menus/_grocery_item.html.haml : si item.previous_quantity_base est présent ET que l'item est
  décoché, affiche un badge ambre discret (charte : ambre réservé aux alertes de ce type est acceptable
  ici car c'est une INFORMATION de notation/attention, style .badge existant) avec le texte :
  « Était <ancienne quantité formatée> — déjà acheté ? ».
  DRY : réutilise le formatage humain de GroceryItem#quantity_display. Si nécessaire, refactore-le en
  une méthode paramétrable (ex. format_quantity(value)) utilisée par quantity_display ET par le badge —
  pas de duplication de la logique de formatage des quantités.
  EFFACEMENT du badge : quand l'utilisateur RE-COCHE l'article, previous_quantity_base doit repasser à nil.
  Implémente ça dans le MODÈLE GroceryItem (callback before_save : si checked passe à true,
  previous_quantity_base := nil) — pas dans le contrôleur (le PATCH de toggle et l'édition de quantité
  passent tous deux par GroceryItemsController#update, le callback couvre tous les chemins).
  Le turbo_frame grocery_item_<id> re-rend le partial après le PATCH : le badge disparaît donc
  automatiquement au re-cochage, vérifie-le.
  ATTENTION compatibilité : si une action groupée « Tout cocher / Tout décocher » existe ou est ajoutée
  plus tard, elle ne doit PAS passer par update_all (contournerait le callback) : utiliser des updates
  individuels ou remettre explicitement previous_quantity_base à nil dans la même opération.

  PARTIE 5 — Retour en brouillon du menu actif
  1. Modèle : ajoute Menu#revert_to_draft! → lève une erreur si le menu n'est pas status_active,
     sinon update!(status: :draft). Les grocery_items sont CONSERVÉS tels quels (coches comprises) :
     c'est la réconciliation de la partie 3 qui les mettra à jour à la revalidation.
  2. Route member POST :revert_to_draft + action contrôleur (réutilise le helper privé transition_menu
     existant) + MenuPolicy#revert_to_draft? (owner?).
  3. Vue _active_view.html.haml (ou barre contextuelle de show.html.haml, choisis l'emplacement le plus
     cohérent avec les actions existantes) : bouton « Modifier ce menu » avec
     turbo_confirm : « Repasser ce menu en brouillon pour le modifier ? À la revalidation, ta liste de
     courses sera mise à jour : les articles déjà cochés le restent, sauf si leur quantité augmente. »
  4. Comme un brouillon peut désormais coexister avec un autre brouillon (celui issu du retour +
     un éventuel brouillon existant), adapte classify_menus et l'index : @drafts = tous les brouillons
     (boucle sur la section « Mon prochain menu »), plus de brouillon invisible orphelin.
     Adapte le guard modal de l'index en conséquence (il référence @draft au singulier).

  PARTIE 6 — Confirmations honnêtes
  1. _draft_view.html.haml, turbo_confirm de validation : le message actuel n'annonce ni la lecture
     seule ni l'archivage. Nouveau message : « Valider ce menu ? La liste de courses sera générée. »
     + s'il s'agit d'une REvalidation (le menu a déjà des grocery_items) : « Ta liste existante sera
     mise à jour en conservant tes articles cochés (sauf quantités augmentées). »
     + si l'utilisateur a déjà un menu actif : « Ton menu actif actuel sera archivé. »
     Construis le message conditionnellement dans la vue ou un helper (pas de JS custom).
  2. Menu#reactivate! (réutilisation d'un menu archivé depuis l'historique) : les coches de ce vieux
     menu sont OBSOLÈTES (courses d'il y a des semaines). Avant l'appel à activate!, décoche tous les
     grocery_items du menu réactivé et remets leurs previous_quantity_base à nil → l'utilisateur repart
     d'une liste fraîche. Ne touche pas au comportement de reactivate côté archivage.

  TESTS (RSpec, le projet utilise spec/) :
  - spec du service : un cas par règle a-f de la partie 3 + idempotence + items manuels intouchés.
  - spec modèle : revert_to_draft! (depuis active OK, depuis draft/archived → erreur),
    callback d'effacement de previous_quantity_base au cochage, reactivate! décoche tout.
  - spec request : POST revert_to_draft (owner OK, non-owner refusé).
  Lance les specs existantes des menus/groceries pour vérifier l'absence de régression
  (le changement de comportement de BuildForMenuService peut en casser — adapte-les si le nouveau
  comportement est le comportement voulu).

  Respecte les règles permanentes du plan (DRY, aucun code mort, variables CSS pour le badge,
  vérifier les types DB avant d'appeler des méthodes dessus).
  ```

- **Vues à vérifier** :
  - `/menus` : badge « Actif » ; plusieurs brouillons listés si applicable ; guard modal fonctionnel.
  - `/menus/:id` (actif) : bouton « Modifier ce menu » → confirm → retour en brouillon avec repas intacts.
  - Parcours complet : valider un menu → cocher des articles (dont un à quantité X) → « Modifier ce menu » → ajouter un repas qui augmente la quantité de cet article → revalider → sur `/menus/:id/grocery` : l'article est **décoché avec badge « Était X — déjà acheté ? »**, les autres articles cochés le sont **restés**, les articles manuels sont intacts ; re-cocher l'article → le badge disparaît.
  - Historique : « Réutiliser ce menu » → liste régénérée **entièrement décochée**.
- **Commit** : `feat: editable active menu with grocery list reconciliation`
- ↳ Dépend de : aucune. Compatibilité vérifiée avec les requêtes restantes : R3.3 (ingrédients), R3.4 (tags) et R3.5 (import IA) ne touchent ni au cycle de vie des menus ni à la liste de courses ; R3.6 (nettoyage) et R3.7 (images) non plus — aucun conflit.

## R3.3 — Ingrédients : scannabilité et saisie des saisons

- **Contexte / fichiers**
  - `ingredients/index.html.haml`, `_form.html.haml`, `ingredients.css`, `components.css` (`.months-grid`)
- **Objectif** : liste plus scannable et saisie des mois de saison plus rapide.
- **📋 Demande à Claude Code**
  ```text
  Améliore les écrans ingrédients.
  1. Liste (/ingredients) : résume la saison en libellé compact (ex. "Mar–Oct" ou mini-calendrier) plutôt qu'une
     liste de mois ; ajoute un compteur de résultats ; compacte les filtres en ligne.
  2. Formulaire (/ingredients/new, edit) : ajoute des raccourcis de saisie des mois — boutons "Toute l'année",
     "Aucun", "Saison actuelle" — et regroupe visuellement par saison (printemps/été/automne/hiver).
  Conserve le Turbo Frame de liste et la logique existante (vérifie le type de season_months en DB).
  Respecte les règles permanentes.
  ```
- **Vues à vérifier** : `/ingredients` (saison résumée, compteur) ; `/ingredients/new` (raccourcis mois).
- **Commit** : `ux: ingredients scannability and season input`

## R3.4 — Tags admin : regroupement et édition inline

- **Contexte / fichiers**
  - `tags/index.html.haml`, `_tags_list.html.haml`, `tags.css`, `tag_inline_controller.js`
- **Objectif** : gestion des tags plus claire (par type, avec compteur), boutons accessibles.
- **📋 Demande à Claude Code**
  ```text
  Améliore l'admin des tags (/tags).
  1. Affiche les tags GROUPÉS par type (rapidité, régime, occasion, méthode de cuisson, saison, autre),
     avec un compteur de recettes par tag si disponible.
  2. Conserve l'édition inline, mais dans chaque groupe.
  3. Remplace les boutons ✓ et × par des icônes SVG avec aria-label ; respecte la sémantique couleur du Lot 1
     (pas d'ambre pour "enregistrer").
  Conserve le Turbo Frame tags_list et le controller tag-inline. Respecte les règles permanentes.
  ```
- **Vues à vérifier** : `/tags` (groupes par type, compteurs, édition inline, icônes).
- **Commit** : `ux: tags admin grouping and inline edit`
- ↳ Dépend de : R1.5, R1.6

## R3.5 — Import IA & brouillons : feedback et priorisation

- **Contexte / fichiers**
  - `recipe_imports/new.html.haml` (onglets emoji, pas d'aperçu, pas d'état loading visible)
  - `recipe_drafts/index.html.haml` (liste peu priorisée)
  - `import_source_controller.js`
- **Objectif** : workflow d'import clair, rassurant, avec retour visuel ; liste de brouillons informative.
- **📋 Demande à Claude Code**
  ```text
  Améliore l'import IA (/recipe_imports/new) et la liste des brouillons (/recipe_drafts).
  1. Import : vrais onglets iconés (URL / Photo) ; aperçu du fichier/photo sélectionné ; état de chargement VISIBLE
     au submit (bouton désactivé + spinner + message "15 à 30 s") pour éviter les double-clics ; message de
     réassurance "tu valideras la recette avant publication".
  2. Brouillons : pour chaque recette importée, affiche source, date, statut de complétude (champs manquants
     éventuels) et une mini-photo si disponible ; priorise visuellement ce qui reste à compléter.
  Respecte la charte et les règles permanentes.
  ```
- **Vues à vérifier** : `/recipe_imports/new` (onglets, aperçu, loading) ; `/recipe_drafts` (infos et complétude).
- **Commit** : `ux: ai import feedback and drafts list`

## R3.6 — Polish final & nettoyage

- **Contexte / fichiers**
  - `home.css` (animations `fadeInUp` jusqu'à ~2s ; règle morte `content: url()` en media mobile)
  - `recipes.css` (bloc mort `.filter-quick-pill` non utilisé par la vue)
  - `select2.css` + `select2_custom.css` : **code mort** — Select2/jQuery remplacé par `searchable_select_controller.js`, aucune vue ne référence select2
  - Empty states pauvres : `ingredients/index`, `tags/index` (simples `%p`) vs riches ailleurs
  - `home/_vitrine.html.haml` (contenu marketing générique)
  - Header mobile : avatar qui sert aussi de menu hamburger (`layouts.css`)
- **Objectif** : cohérence finale, suppression du code mort, vitrine plus concrète.
- **📋 Demande à Claude Code**
  ```text
  Finalise le polish et nettoie.
  1. Raccourcis les animations d'accueil (fadeInUp échelonnés jusqu'à ~2s) à 0.4–0.6s.
  2. Standardise les empty states d'ingredients/index et tags/index sur le modèle riche existant
     (icône SVG + titre + texte + CTA).
  3. Supprime le code mort CSS : bloc .filter-quick-pill (recipes.css) inutilisé, règle mobile "content: url()"
     redondante (home.css), et tout autre résidu que tu repères.
  4. Supprime select2.css et select2_custom.css : Select2/jQuery a été remplacé par searchable_select_controller
     et aucune vue ne référence de classe .select2-*. VÉRIFIE d'abord qu'aucune classe n'est générée dynamiquement
     (grep dans les vues, helpers et controllers JS) avant de supprimer, et retire leur référencement du pipeline.
  5. Vitrine (visiteur non connecté) : rends la valeur plus concrète (aperçu d'un menu / extrait de liste de courses,
     photo culinaire lisible) plutôt que du texte marketing générique.
  6. Clarté nav mobile : distingue visuellement "profil" et "menu de navigation" (hamburger) si ambigu.
  Respecte les règles permanentes ; vérifie qu'aucune classe encore utilisée n'est supprimée.
  ```
- **Vues à vérifier** : `/` (visiteur + connecté), `/ingredients` (vide), `/tags` (vide), header mobile.
- **Commit** : `chore: polish animations, empty states and cleanup`
- ↳ Dépend de : R1.6 (icônes des empty states)

## R3.7 — Images responsive et performance

- **Contexte / fichiers**
  - `recipes/index.html.haml` (seules 2 images ont `loading: "lazy"` — à généraliser)
  - `recipes/show.html.haml`, vues menus (`_menu_recipe_card`), brouillons (`recipe_drafts/index`)
  - Active Storage (photos de recettes)
- **Objectif** : images légères et sans layout shift sur mobile (crucial en PWA / connexion magasin).
- **📋 Demande à Claude Code**
  ```text
  Optimise les images de l'app.
  0. Traite en priorité les DEUX assets statiques les plus lourds (relevés à l'audit Lighthouse R0.5, ce sont
     les plus gros poids réseau de l'app) — ce sont des assets du pipeline, PAS des photos Active Storage :
     - app/assets/.../backgrounds/kitchen_2.jpg (~1,4 Mo, image LCP de l'accueil)
     - app/assets/.../photo_par_defaut_recette*.png (~2,2 Mo, placeholder "photo par défaut" affiché sur /recipes
       et /menus/:id en 179×119 alors qu'il fait 1021×1024)
     Convertis-les en WebP/AVIF (cible ~250 Ko) ou augmente fortement la compression + redimensionne à la taille
     réellement affichée.
     Pour les photos de recettes servies par Cloudinary (déjà en c_fill/w_/h_), demande la taille adaptée à
     l'affichage (elles sont servies en 260×260/400px pour un rendu ~119px) et ajoute srcset/sizes (voir pt 4).
  1. Généralise loading="lazy" sur toutes les images sous la ligne de flottaison (cartes recettes, cartes menu,
     brouillons, avis) — PAS sur l'image hero/principale au-dessus du pli.
  2. Ajoute des attributs width/height (ou aspect-ratio CSS) sur les images pour éliminer le layout shift (CLS).
  3. Sers des variantes Active Storage adaptées (variant resize_to_fill/limit) pour les vignettes au lieu des
     photos pleine taille : définis 2-3 tailles standard (vignette carte, medium fiche) et utilise-les partout.
     Vérifie que le processeur d'images (image_processing/vips) est bien disponible avant de générer des variants.
  4. Si simple à faire, ajoute srcset/sizes sur les cartes recettes pour servir la bonne taille selon l'écran.
  Respecte les règles permanentes. Vérifie visuellement le catalogue et la fiche recette (pas d'images floues/étirées).
  ```
- **Vues à vérifier** : `/recipes` (scroll : lazy loading, pas de CLS), `/recipes/:id`, `/menus/:id` — DevTools > Network (poids des images réduit).
- **Commit** : `perf: responsive images with lazy loading and variants`

---

## Récapitulatif des commits (dans l'ordre)

| #       | Commit                                                           | Lot        |
| ------- | ---------------------------------------------------------------- | ---------- |
| R0.1    | `pwa: fix and customize web app manifest` ✅                     | PWA        |
| R0.1bis | `pwa: manifest id, maskable icon and shortcut icons`             | PWA        |
| R0.2    | `pwa: register service worker with offline app shell`            | PWA        |
| R0.3    | `pwa: offline support for grocery list` (reportable après Lot 1) | PWA        |
| R0.4    | `pwa: head meta for ios, safe-area and open graph`               | PWA        |
| R0.5    | `pwa: fix lighthouse audit findings` ✅ (validé, sans commit)    | PWA        |
| R1.1    | `style: unify base font family`                                  | Fondations |
| R1.2    | `style: rework typographic scale and sizes`                      | Fondations |
| R1.3    | `a11y: language, focus states, contrast, aria`                   | Fondations |
| R1.4    | `style: dedupe form rules, fix fixed widths and borders`         | Fondations |
| R1.5    | `style: consolidate button system and color semantics`           | Fondations |
| R1.6    | `style: replace UI emojis with SVG icons`                        | Fondations |
| R1.7    | `refactor: convert devise views to haml`                         | Fondations |
| R2.1    | `feat: actionable connected home dashboard`                      | Parcours   |
| R2.2    | `feat: grocery list action bar and usability`                    | Parcours   |
| R2.3    | `refactor: unify menu params form (generate/regenerate)`         | Parcours   |
| R2.4    | `feat: recipe page sticky ingredients and share`                 | Parcours   |
| R2.5    | `a11y: menu reorder controls and sticky validate`                | Parcours   |
| R3.1    | `ux: streamline sign-up form`                                    | Polish     |
| R3.2    | `ux: recipe cards and filter sidebar polish`                     | Polish     |
| R3.2bis | `feat: editable active menu with grocery list reconciliation`    | Polish     |
| R3.3    | `ux: ingredients scannability and season input`                  | Polish     |
| R3.4    | `ux: tags admin grouping and inline edit`                        | Polish     |
| R3.5    | `ux: ai import feedback and drafts list`                         | Polish     |
| R3.6    | `chore: polish animations, empty states and cleanup`             | Polish     |
| R3.7    | `perf: responsive images with lazy loading and variants`         | Polish     |
