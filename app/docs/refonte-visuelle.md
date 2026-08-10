# EasyMeal — refonte visuelle (v3)

Document de spécification. Toutes les valeurs de couleur et de contraste sont
calculées et vérifiées (WCAG 2.1 : 4.5:1 texte, 3:1 interface).

**Décisions actées :**
- Display : Fraunces. Corps : pile système conservée. Données numériques : DM Mono.
- Couleur d'action : anthracite `--color-primary`. Inchangé.
- Accent : ambre `#FBBF24`. Inchangé. C'est le `warning` qui se déplace vers l'orange.
- Neutres : rampe unifiée sur la teinte 70° en OKLCH.
- Hero : deux variantes distinctes, dashboard et vitrine, sur une primitive commune.

---

## ORDRE D'EXÉCUTION

Les lots sont numérotés par thème, **pas par dépendance**. Exécute dans cet ordre :

```
1.  LOT 2   couleurs          autonome, le plus utile
2.  LOT 1   police            prérequis du LOT 3
3.  LOT 3   typographie       dépend du LOT 1
4.  LOT 4   hero              dépend des LOTS 2 et 3
5.  LOT 5   finitions
```

Un lot = une session = un commit. `/clear` entre chaque : le contexte du LOT 2 ne
sert à rien au LOT 4 et augmente les chances de modifications hors périmètre.
Ne commit pas à la place de Caroline : elle relit le diff et rédige le message.

**Le périmètre négatif est la partie la plus importante de chaque prompt.** Chaque
lot signale explicitement ce qu'il ne faut pas toucher. Un problème repéré en
passant se signale, il ne se corrige pas dans le même diff.

---

## CONTRAINTES ÉTABLIES DU PROJET

Constatées par reconnaissance. À ne pas re-découvrir, mais à re-vérifier si le
projet a bougé.

**Pipeline.** Rails 7.2.3, Sprockets 4.2.2 (pas Propshaft), sassc 2.4.0,
importmap-rails. La déclaration Sprockets réelle est `app/assets/config/manifest.js` :
`link_tree ../images`, `link_directory ../stylesheets .css`, `link_tree ../../javascript .js`.
**Il n'existe ni `app/assets/fonts` ni `vendor/assets`.**

**Cascade CSS.** Manifeste `application.css:13-27`. Ordre :
`variables → global → layouts → components → context_bar → home → ingredients →
recipes → tags → users → authentication → menus → grocery_items → pwa`.
`variables` est en premier ; `menus` et `recipes` sont en fin de chaîne et
**gagnent donc à spécificité égale**. Les feuilles sont en `.css`, pas en `.scss`.

**Service worker.** `app/views/pwa/service-worker.js.erb`, servi sur `/service-worker`.
Trois mécaniques à connaître :
- `cache_version = SHA1(precache_urls.join + sw_revision)[0,12]` — ajouter une URL
  au precache fait tourner le cache seul, sans bumper `sw_revision`.
- `install` fait `cache.addAll(PRECACHE_URLS)` : **une seule URL en 404 fait échouer
  l'installation du service worker entier.**
- La classification `fetch` est par URL : `/assets/*` ou toute URL avec extension →
  cache-first. Un `.woff2` sous `/assets/` tombe déjà dans la bonne branche, rien
  à changer côté stratégie.

**Layout et navbar.** `app/views/layouts/application.html.haml`. La navbar n'est pas
un partial : elle est écrite en dur, L60-137, en **deux branches complètes**
(`user_signed_in?` → `.main-header` ; sinon → `.main-header.auth-header`). Toute
retouche structurelle de nav se fait à deux endroits.

**Home.** `app/views/home/index.html.haml`, avec deux partials mutuellement
exclusifs : `_dashboard` (signé, qui délègue à `_dashboard_active` /
`_dashboard_draft`) et `_vitrine` (visiteur). CSS : `home.css`.

**Header sticky.** `sticky_header_controller.js` publie `--header-height` sur
`document.documentElement` (style inline sur `<html>`, qui bat le `:root`), valeur
arrondie de `getBoundingClientRect().height`, posée dès le `connect` via
`ResizeObserver`. Le header porte déjà `env(safe-area-inset-top)` dans son padding :
**la zone sûre est incluse dans la hauteur mesurée**, ne la rajoute pas.
Repli statique 60px. Consommateurs : `scroll-padding-top` global et trois sidebars
sticky de `recipes.css`.

**Modèle de référence pour les tokens locaux.** `menus.css:2307-2345`, couleurs de
jour. Quatre rôles nommés `--day-accent` / `--day-tint` / `--day-deep` / `--day-edge`,
générés en OKLCH puis **convertis en sRGB en dur** — justification écrite : une
déclaration `oklch()` invalide ferait retomber les sept jours sur le même gris.
Neutre par défaut porté par `.mc-recipe-card` lui-même, ce qui couvre `data-day`
absent et `data-day=""` d'un seul sélecteur. Volontairement pas des tokens globaux.

**Volumétrie des tokens à modifier.**

| Token | Définitions | Usages | Fichiers |
|---|---|---|---|
| `--color-accent*` | 4 | 33 | menus 17, recipes 14, components 4, home 2, pwa 1, layouts 1, global 1 |
| `--color-warning*` | 3 | 8 | recipes 5, menus 2, users 1, global 1 |
| `--color-diet-*` | 6 | 11 | `menus.css` uniquement |
| `--color-icon-violet*` | 2 | 4 | `menus.css` uniquement |
| `--color-ink-3` | 1 | 127 | 12 fichiers + `offline.html.haml` |
| `--font-sans` | 1 | 1 | `global.css:15` (body) |

Deux enseignements. `--color-accent` a 33 usages dans 7 fichiers : c'est ce qui
rend le maintien de l'ambre prudent, et le déplacement du `warning` (8 usages)
bon marché. Et `--font-sans` a un consommateur unique : ajouter `--font-serif` est
une opération propre.

---

## LOT 2 — Couleurs

Fichier : `app/assets/stylesheets/variables.css`, plus `menus.css` pour le 2.5 et
`pwa.css` pour le 2.10.

### 2.1 Neutres : unifier la teinte à 70°

Ta rampe dérive de 49° à 95° en OKLCH : `--color-bg-main` et `--color-bg-secondary`
sont à 91-95°, tout le reste à 49-68°. Concrètement, tes fonds tirent vers le
jaune-vert alors que tes gris tirent vers l'orange. Imperceptible sur un swatch
isolé, très perceptible sur une page entière — c'est la cause de l'effet
« blanc sale ».

Second problème, indépendant : blanc sur `#F8F7F4` donne 1,07:1. Tes surfaces
blanches n'existent pas visuellement. Cible : ~1,20:1.

```css
:root {
  /* --- Neutres : teinte 70° unifiée --- */
  --color-bg-main:       #F0EAE3;  /* était #F8F7F4 — oklch(0.940 0.012 70) */
  --color-bg-secondary:  #E8E2DB;  /* était #F1F0EC */
  --color-bg-tertiary:   #E0D9D1;  /* était #E7E5E4 */
  --color-bg-white:      #FFFFFF;  /* inchangé */

  --color-border-light:  #E8E2DB;  /* était #F1F0EC */
  --color-border:        #DCD5CD;  /* était #E7E5E4 */
  --color-border-strong: #C9C1B8;  /* était #D6D3D1 */

  --color-ink:           #1C1916;  /* était #1C1917 */
  --color-ink-2:         #45403B;  /* était #44403C */
  --color-ink-3:         #615B54;  /* était #6B645E — voir 2.2 */
  --color-ink-4:         #A9A29A;  /* était #A8A29E */

  --color-primary:       #1C1916;
  --color-primary-hover: #45403B;
  --color-primary-light: rgba(28, 25, 22, 0.08);

  --color-secondary:       #E8E2DB;
  --color-secondary-hover: #E0D9D1;
  --color-secondary-text:  #45403B;

  --color-surface-dark:              #292521;
  --color-surface-dark-border:       #393530;
  --color-surface-dark-border-hover: #57524C;
  --color-ink-on-dark:               #D5CEC6;
  /* --color-danger-on-dark et --color-danger-border-dark : inchangés,
     le rouge ne suit pas la teinte des neutres. */
}
```

**Note sur le rayon d'action.** `--color-ink-3` a 127 usages. C'est un changement de
valeur, pas un renommage, donc sans risque de casse — mais l'assombrissement se
verra partout dans l'app. C'est voulu (plus de contraste), à regarder quand même.

### 2.2 `--color-ink-3` : préserver le correctif AA existant

`variables.css` documente l'assombrissement de `#78716C` vers `#6B645E` pour
atteindre AA sur `#F8F7F4` / `#F1F0EC` (audit Lighthouse R1.3). Les fonds plus
sombres du 2.1 annulent ce travail :

| `#6B645E` sur… | Contraste |
|---|---|
| `#F0EAE3` nouveau bg-main | 4,88:1 ✓ |
| `#E8E2DB` nouveau bg-secondary | 4,53:1 — limite |
| `#E0D9D1` nouveau bg-tertiary | **4,16:1 ✗** |

Remonter les fonds ne résout rien : on plafonne à 4,37:1 sur tertiary tout en
reperdant la hiérarchie de surface. La correction passe par `ink-3`.

`#615B54` — `oklch(0.475 0.014 70)` — donne 5,61:1 / 5,21:1 / 4,79:1. AA sur les
trois surfaces claires, avec de la marge.

**Mets à jour le commentaire existant.** Il cite `#F8F7F4` et `#F1F0EC`, qui n'existent
plus. Un commentaire qui documente des valeurs disparues est un piège pour la
prochaine lecture.

### 2.3 Accent et warning : ce qui change vraiment

La charte est explicite : anthracite comme couleur principale, ambre comme seul
accent coloré. Les boutons d'action sont en `--color-primary` et l'ambre est un
highlight, jamais un remplissage interactif. **L'accent reste l'ambre.**

Le corail du logo ne doit **pas** être promu en accent. Mesuré en OKLCH :

| Paire | Écart de teinte | Écart de luminosité |
|---|---|---|
| Ambre `#FBBF24` / warning `#F59E0B` | 14,3° | 0,068 |
| Corail `#D73747` / danger `#DC2626` | **6,7°** | **0,008** |

Promouvoir le corail échangerait une confusion accent/avertissement contre une
confusion action/action destructive, deux fois plus rapprochée — sur une app où
l'on supprime des recettes. Le rapport de reconnaissance confirme le coût : 33
usages dans 7 fichiers.

Le problème réel est la duplication de valeurs. Aujourd'hui
`--color-accent-light` et `--color-warning-light` sont le même `#FEF3C7`, et
`--color-accent-text` et `--color-warning-text` le même `#92400E`. Deux noms de
rôle, un seul jeu de valeurs : il n'y a donc pas deux rôles, mais un avec deux noms.
La correction est de déplacer le `warning` vers l'orange — 8 usages, le changement
le moins cher du lot.

```css
:root {
  /* --- Accent : ambre, highlight de marque. Valeurs conservées. --- */
  --color-accent:        #FBBF24;
  --color-accent-hover:  #F59E0B;
  --color-accent-light:  #FEF3C7;
  --color-accent-border: #FCD34D;   /* nouveau */
  --color-accent-text:   #92400E;
  --color-on-accent:     #1C1916;   /* nouveau — jamais de blanc sur l'ambre */

  /* --- Warning : déplacé vers l'orange, oklch(_ _ 56) --- */
  --color-warning:        #EB7D06;  /* était #F59E0B */
  --color-warning-hover:  #C96900;  /* nouveau */
  --color-warning-light:  #FFEDDE;  /* était #FEF3C7, doublon de accent-light */
  --color-warning-border: #FBC48E;  /* nouveau */
  --color-warning-text:   #823600;  /* était #92400E, doublon de accent-text */
  --color-on-warning:     #1C1916;  /* nouveau */
}
```

Séparations obtenues : warning/accent 28,4° · warning/danger 28,7°.
Contrastes : `#823600` sur `#FFEDDE` = 7,44:1 · `#1C1916` sur `#EB7D06` = 6,22:1.

### 2.4 Le corail du logo garde un rôle, mais décoratif

`--color-diet-selected: #D73A49` est la couleur du logotype, employée dans un rôle
fonctionnel minuscule. Renomme-la pour ce qu'elle est, sans lui donner de rôle
sémantique :

```css
--color-brand:       #D73A49;  /* corail du logotype */
--color-brand-light: #FFF8F8;  /* ex --color-diet-selected-bg */
```

Usages autorisés : état sélectionné des options de régime, moments décoratifs de
marque. **Jamais** sur un bouton, un lien, ou un état d'erreur.

### 2.5 Régimes alimentaires : générer, renommer, déplacer

Trois corrections, à faire ensemble.

**Générer.** Les cinq `--color-diet-*-bg` actuels ne sont pas cohérents
perceptuellement : `#EDF7E6` et `#E6F5EE` n'ont pas la même luminosité perçue,
donc le végétarien « saute » plus que le vegan alors qu'ils devraient peser pareil.

**Renommer selon la convention des couleurs de jour.** `menus.css:2307` établit
déjà quatre rôles pour ce problème exact : `accent` / `tint` / `deep` / `edge`.
Réutilise-les au lieu d'introduire une seconde convention à 2000 lignes d'écart
dans le même fichier.

```
--diet-tint    fond de la pastille          L 0.955 / C 0.030
--diet-edge    bordure de la pastille       L 0.885 / C 0.070
--diet-deep    texte de la pastille         L 0.430 / C 0.130
--diet-accent  aplat vif, état sélectionné  L 0.585 / C 0.190
```

| Régime | Teinte | tint | edge | deep | Contraste deep/tint |
|---|---|---|---|---|---|
| omnivore | 25° | `#FFE9E6` | `#FFC8C2` | `#892A29` | 7,44:1 |
| végétarien | 125° | `#EBF4DE` | `#CEE2B0` | `#405B00` | 6,83:1 |
| vegan | 165° | `#DFF7EB` | `#AEE8CE` | `#00643D` | 6,45:1 |
| pescétarien | 245° | `#E0F3FF` | `#B3DFFF` | `#005391` | 6,97:1 |
| (slot libre) | 310° | `#F6EBFF` | `#E7CDFC` | `#653784` | 7,50:1 |

Comme pour les couleurs de jour : **hex en dur, formule OKLCH en commentaire**, pour
la raison déjà écrite dans `menus.css` — une `oklch()` invalide ferait retomber tous
les régimes sur le même gris.

**Déplacer.** Ces tokens sont dans `variables.css` alors que leurs 11 usages sont
tous dans `menus.css`. C'est exactement la situation que les couleurs de jour
évitent, avec la justification déjà écrite au-dessus. Déplace-les dans `menus.css`,
à côté du bloc des couleurs de jour.

### 2.5 bis — Découper en deux temps

Les colonnes `edge` et `deep` du tableau ci-dessus n'ont **aucun consommateur
aujourd'hui** : les six tokens actuels sont tous des fonds. Les introduire suppose
donc de restyler les chips de régime, c'est-à-dire de toucher au balisage et aux
règles du composant — ce qui n'est pas le sujet d'un lot de tokens, et ce qui rendrait
le diff du LOT 2 impossible à relire.

**Dans le LOT 2, faire uniquement le temps A :**

- renommer les **4 tokens de teinte** existants selon la convention
  `--diet-{régime}-tint` (les 2 autres, `selected` et `selected-bg`, deviennent
  `--color-brand(-light)` au 2.4)
- remplacer leurs valeurs par la colonne `tint` du tableau
- les déplacer dans `menus.css`
- reprendre le motif du neutre par défaut porté par l'élément lui-même : il couvre
  l'attribut absent et l'attribut vide d'un seul sélecteur

C'est une substitution 1 pour 1 : même nombre de tokens, même rôle, mêmes points de
consommation. Le seul effet visible est l'harmonisation des luminosités.

**Le temps B — ajouter `edge`, `deep`, `accent` et restyler les chips — est un
chantier séparé.** Avant de le spécifier, il faut voir le balisage et le CSS
actuels des chips de régime. Ne pas l'entamer dans le LOT 2.

### 2.6 `--color-icon-violet` : renommer et déplacer

2 définitions, 4 usages, tous dans `menus.css`. Même traitement que les régimes :

- `--color-icon-violet` → `--color-category-icon`
- `--color-icon-violet-bg` → `--color-category-icon-bg`
- déplacer dans `menus.css`

Un token se nomme par son rôle, pas par son apparence : le jour où cette pastille
passe au bleu, un token nommé `violet` devient un mensonge impossible à corriger
sans rename global.

### 2.7 Contrat uniforme des rôles

`danger` a 6 variantes, `success` 3, `info` 3, `accent` 6 après le 2.3. Un système
où chaque rôle a une forme différente force à relire le fichier de tokens à chaque
usage. Signature à appliquer à `accent`, `warning`, `success`, `danger`, `info` :

```
--color-{role}
--color-{role}-hover
--color-{role}-light
--color-{role}-border
--color-{role}-text
--color-on-{role}
```

**Le contrat n'est pas mécanique.** Un token se justifie s'il empêche une valeur
en dur prévisible ou une erreur d'accessibilité — pas parce qu'une colonne du
tableau serait vide. Appliqué :

- `-border` : à créer partout. Justification empirique — l'audit a trouvé
  `border: 1px solid #FCD34D` en dur pour un rôle sans token de bordure.
- `on-{role}` : à créer partout. Garde-fou d'accessibilité : leur absence est
  exactement ce qui produit du texte blanc sur de l'ambre.
- `-hover` : **uniquement sur les rôles actionnables.** `success`, `info` et
  `warning` sont des états, pas des actions — un message de succès ne se survole
  pas. Ne pas créer `--color-success-hover`, `--color-info-hover` ni
  `--color-warning-hover`.

`--color-on-info` doit valoir `#1C1916` et non `#FFFFFF` : blanc sur
`--color-info` ne donne que 3,68:1, l'encre foncée donne 4,76:1. Pour passer au
blanc un jour, il faudrait assombrir `--color-info` vers `#2563EB` (5,17:1) —
autre chantier.

**Reliquats à supprimer** après vérification d'usage nul : `--color-danger-bg-hover`,
`--color-danger-border-dark`, `--color-success-hover`, `--color-info-hover`,
`--color-warning-hover`.

`--color-accent-hover` **n'est pas un reliquat** : 9 usages. Il relève du 2.13.

### 2.8 Focus ring : extraire, ne pas ajouter

**Correction d'une erreur des versions précédentes de ce document.** La règle
`:focus-visible` **existe déjà** dans `global.css`, section « ACCESSIBILITÉ GLOBALE
(R1.3) », avec `outline: 2px solid var(--color-primary)` et une liste de sélecteurs
de composants (`.active-filter-badge`, `.filter-tag-check-label`,
`.recipe-card-link`). Le mécanisme est en place et correct.

Ce qui manque est uniquement le **token**. Ajouter une nouvelle règle serait une
erreur — et une règle en `:where()` serait carrément du code mort, puisque sa
spécificité de zéro la ferait perdre contre la règle existante.

```css
/* variables.css */
--color-focus-ring: #1C1916;   /* = --color-primary, isolé pour pouvoir divergrer */
```

Puis, dans `global.css`, remplacer `var(--color-primary)` par
`var(--color-focus-ring)` dans le bloc existant. Ne pas toucher à la liste de
sélecteurs.

**Incohérence à corriger dans le même geste.** `.skip-link:focus` utilise
`outline: 2px solid var(--color-accent)` alors que tout le reste utilise
`--color-primary`. Or `outline-offset: 2px` place une partie du contour sur le fond
de page, et l'ambre y échoue :

| `#FBBF24` sur… | Contraste | Seuil UI 3:1 |
|---|---|---|
| `#F0EAE3` nouveau bg-main | 1,40:1 | ✗ |
| `#FFFFFF` surface blanche | 1,67:1 | ✗ |
| `#1C1917` le skip-link lui-même | 10,48:1 | ✓ |

Le contour d'accessibilité du lien d'accessibilité est le seul élément non conforme
du bloc accessibilité. Passer sur `var(--color-focus-ring)` comme les autres :
14,65:1 sur `bg-main`.

**Vérifier aussi** les `outline: none`. Les poses sur règle de base sont
inoffensives (le `:focus-visible` global les bat), mais toute règle
`…:focus { outline: none }` dans `recipes.css`, `menus.css`, `tags.css` ou
`ingredients.css` **gagne** : à spécificité égale, ces feuilles passent après
`global.css` dans la cascade. Les recenser ici, les corriger au LOT 5.3 bis.

### 2.9 Ombres : les teinter

Les trois ombres sont en noir pur. Sur une palette neutre froide c'est correct ;
sur des fonds à 70° de teinte, un gris parfaitement neutre lit légèrement bleuté
et éteint la chaleur du fond.

```css
--shadow-sm: 0 1px 2px rgba(28, 25, 22, 0.05);
--shadow-md: 0 1px 4px rgba(28, 25, 22, 0.07);
--shadow-lg: 0 2px 8px rgba(28, 25, 22, 0.09);
```

Alphas très légèrement relevés : une ombre teintée paraît plus faible qu'une ombre
neutre à luminosité égale. À valider à l'œil, pas au ratio.

### 2.10 Supprimer le fallback de `pwa.css`

`pwa.css` contient **5 fallbacks** de ce type — sur `--color-ink`, `--shadow-lg`,
`--color-ink-2`, `--color-danger` et `--color-accent`. Chacun duplique la valeur de
son token, donc aucun ne suivra le jour où le token change. Inoffensifs aujourd'hui,
pièges dormants demain. Retirer les cinq.

### 2.11 Première tâche du lot : audit des couleurs en dur

**Prérequis bloquant.** Le LOT 2 repose sur l'idée que modifier un token modifie
tout ce qui en dépend. `global.css` prouve que c'est faux : il contient 8 couleurs
sémantiques écrites en dur, dont certaines dupliquent des tokens et d'autres les
contredisent. Rien ne garantit que les 12 autres feuilles soient plus propres.

```
Dans toutes les feuilles de app/assets/stylesheets/, liste chaque couleur
écrite en dur (hex, rgb, rgba, hsl, nom CSS), avec fichier, ligne, propriété
et sélecteur. Exclus variables.css.

Pour chacune, indique s'il existe un token de la palette qui a exactement
cette valeur, ou qui remplit ce rôle avec une valeur différente.

Sépare le résultat en trois groupes :
  A. duplique exactement un token existant   -> remplacer par var()
  B. remplit le rôle d'un token, valeur differente -> à décider une par une
  C. aucun token correspondant               -> laisser, signaler

Puis, séparément : montre-moi les 8 usages de --color-warning* avec 3 lignes
de contexte, et dis-moi lesquels cohabitent avec une couleur en dur.

Ne modifie aucun fichier.
```

Le groupe B est le seul qui demande un arbitrage, et c'est celui qui compte : une
valeur en dur qui *diverge* du token de son rôle est une seconde palette clandestine.

Le dernier point n'est pas une formalité : `--color-warning` change de teinte, et
tout endroit où il cohabite avec une couleur en dur va se désaccorder. Cas déjà
identifié en 2.12.

### 2.12 `global.css` — corrections identifiées

À traiter dans ce lot, les constats étant déjà faits.

**Le flash warning va casser.** `.flash-message.warning` a un
`background-color: #fef3c7` en dur et un `border-left-color: var(--color-warning)`.
Après le 2.3, la bordure passe à l'orange et le fond reste ambre : 39,4° d'écart de
teinte, visiblement faux. Remplacer le fond par `var(--color-warning-light)` et le
texte par `var(--color-warning-text)`.

**Les quatre flashs sont une seconde palette.** Comparaison des valeurs en dur avec
les tokens de même rôle :

| | Flash (en dur) | Token | Constat |
|---|---|---|---|
| notice / success | `#d1fae5` / `#065f46` | `#ECFCCB` / `#365314` | deux verts différents (emerald vs lime) |
| alert / danger | `#fee2e2` / `#991b1b` | `#FEF2F2` / `#991B1B` | texte identique, fond différent |
| info | `#dbeafe` / `#1e40af` | `#EFF6FF` / `#1E40AF` | texte identique, fond différent |
| warning | `#fef3c7` / `#92400e` | `#FEF3C7` / `#92400E` | identiques |

Les trois premiers relèvent du groupe B de l'audit : la valeur en dur remplit le
rôle du token mais diverge. Le cas `success` est le plus net — le vert des toasts
n'est pas le vert du design system.

Recommandation : basculer les quatre sur `var(--color-{role}-light)` et
`var(--color-{role}-text)`. Les fonds vont légèrement s'éclaircir (les tokens sont
en `-50`, les valeurs en dur en `-100`) ; si les toasts paraissent alors trop pâles,
la bonne réponse est d'ajuster le token, pas de réintroduire une valeur en dur.

**Deux tokens fantômes.** `body > p.notice` et `body > p.alert` référencent
`var(--success-border)` et `var(--error-border)`, **qui n'existent pas** dans
`variables.css`. La déclaration devient invalide et retombe sur `currentColor` — soit
exactement ce que `border-bottom: 1px solid` sans couleur produisait déjà. Ça
fonctionne par accident. Remplacer par `var(--color-success)` et
`var(--color-danger)`, ou supprimer les deux déclarations.

**`#FFFFFF` en dur dans `.skip-link`** (2 occurrences) : remplacer par
`var(--color-bg-white)`.

### 2.13 `--color-accent-hover` : un nom pour trois rôles

Constat de l'audit : 9 usages, dont **un seul est un vrai survol**
(`.btn-accent:hover`, `components.css:107`). Les huit autres s'en servent comme
ambre foncé statique — bordure de carte brouillon, séparateur de kicker, chip mise
en avant, cible de drop. Un second rôle a pris le nom du premier.

Ces neuf usages ne tombent pas dans un rôle unique, mais dans **trois** :

| Usages | Nature | Cible |
|---|---|---|
| `components.css:107` | vrai survol | `--color-accent-hover` (inchangé) |
| `menus.css:194, 254, 1300, 1645, 2409-2410`, `recipes.css:2638` | bordure ou fond décoratif | `--color-accent-deep` (nouveau) |
| `menus.css:1289` `.mn-page-kicker` | **texte** | voir ci-dessous |

```css
--color-accent-deep: #F59E0B;  /* ambre foncé statique, non interactif.
                                  Même valeur que -hover, sens différent :
                                  aliasing volontaire, cf. critères ci-dessous. */
```

**Pourquoi séparer alors que rien ne bouge visuellement.** `#F59E0B` n'est qu'à
**13,9° du nouveau `--color-warning`** (`#EB7D06`), et cette collision est vivante
sur sept bordures : une bordure de carte brouillon et un badge d'avertissement à 14°
d'écart. Isoler `--color-accent-deep` permettra de le décaler plus tard sans toucher
au survol. Sans le split, c'est impossible.

**Le cas du kicker.** `.mn-page-kicker` utilise ce token en **couleur de texte** :

| `#F59E0B` sur… | Contraste | Verdict |
|---|---|---|
| `#F0EAE3` bg-main | 1,80:1 | ✗ |
| `#FFFFFF` surface blanche | 2,15:1 | ✗ |
| `#292521` surface-dark | 7,08:1 | ✓ |

Vérifier sur quelle surface le kicker est rendu. Sur clair → `--color-accent-text`
(`#92400E`). Sur sombre → `--color-accent-deep` convient.

Décaler la teinte ne réglera pas ce cas : un ambre reste à ~2,2:1 sur fond clair
quelle que soit sa teinte (mesuré à 84°, 88° et 92°). Pour du texte ambré sur clair,
`--color-accent-text` est la seule réponse.

### Critère de validation du LOT 2

- Aucun couple de **rôles sémantiques** (`accent`, `warning`, `success`, `danger`,
  `info`) ne partage une valeur. L'aliasing de la rampe neutre — plusieurs noms sur
  une même valeur neutre — est sain et ne compte pas : trois tokens de même valeur
  restent indépendamment modifiables, c'est l'intérêt de les nommer.
- `ink-3` passe AA sur `bg-main`, `bg-secondary` et `bg-tertiary`.
- Chaque token vit **à l'échelle de son sens**, pas de son usage actuel. Les teintes
  de régime ne signifient rien hors des chips → `menus.css`. Le corail du logotype
  signifie quelque chose partout, même s'il ne s'affiche aujourd'hui qu'à un endroit
  → `variables.css`.
- Aucun `var()` ne référence un token inexistant.
- Le commentaire de `ink-3` cite les nouvelles valeurs.
- Le flash warning est cohérent avec la nouvelle teinte orange.

---

## LOT 2 bis — Reconvergence des couleurs en dur

L'objet du LOT 2 était d'unifier la teinte des neutres. Laisser des valeurs neutres
hors rampe, c'est ne pas l'avoir fait. Ce lot n'est donc pas une suite optionnelle :
c'est la fin du LOT 2.

**Deux commits séparés, parce qu'ils se relisent différemment.**

### 2bis-A — Groupe A : substitutions mécaniques

Les ~42 occurrences restantes qui dupliquent exactement un token, dont 27 `#FFFFFF`
vers `--color-bg-white`. Aucune décision. Gros diff, relecture par échantillonnage.

Y ajouter `#FCD34D` (`recipes.css:3367`), qui duplique désormais exactement
`--color-accent-border`, et les six `rgba(28, 25, 23, …)` devenus
`rgba(28, 25, 22, …)`.

Interdit : profiter du passage pour toucher à autre chose.

### 2bis-B — Groupe B : arbitrage par occurrence

**Ne pas mapper par luminosité. Mapper par rôle.** C'est le piège de cette
substitution :

| En dur | Sur `#F0EAE3` | Voisin en luminosité | Rôle réel |
|---|---|---|---|
| `#666` | 4,81:1 ✓ | `ink-3` (5,61:1) | texte secondaire |
| `#888` | **2,97:1 ✗** | `ink-4` (2,11:1) | texte secondaire |
| `#999` | **2,39:1 ✗** | `ink-4` (2,11:1) | texte secondaire |
| `#78716C` | **4,02:1 ✗** | `ink-3` (5,61:1) | texte secondaire |
| `#D1D5DB` | — | `border-strong` | bordure |

`#888` et `#999` portent du texte et **échouent déjà AA**. Les mapper vers leur
voisin `--color-ink-4` (2,11:1) ne corrigerait rien : ça inscrirait l'échec dans le
design system, avec un token que le 5.2 déclare décoratif uniquement.

**Règle :** toute valeur en dur portant du **texte** va vers `--color-ink-3`, quelle
que soit sa luminosité d'origine. Elles vont visiblement s'assombrir, et c'est le
but — ce sont des corrections d'accessibilité déguisées en harmonisation de teinte.
Seules les occurrences purement décoratives (icône, séparateur) vont vers `ink-4`.

Donc : lecture du rôle à chaque site, pas de rechercher-remplacer.

`#78716C` mérite une mention : c'est la valeur que l'audit R1.3 avait rejetée,
réintroduite en dur à deux endroits. Mode d'échec canonique — on corrige le token,
on oublie les copies.

Restent à trancher au cas par cas : `#1D4ED8` et `#A3E635` (`recipes.css:3382,3401`),
divergents d'un cran de `--color-info-text` et `--color-success-border`, et
`#D73A49` en dur dans `_diet_icon.html.haml:9`, qu'un attribut `fill` peut consommer
via `style="fill: var(--color-brand)"` ou `currentColor`.

### Hors périmètre de ce lot

- Les ~35 `rgba(0,0,0,…)` d'ombres et de voiles : groupe C, aucun token
  correspondant. Une partie recopie `--shadow-*` à l'alpha près et mériterait une
  tokenisation, mais c'est un chantier propre.
- Les ~10 `rgba(255,255,255,…)` d'effets de verre : pas de token d'opacité dans la
  palette. Même remarque.
- Les 22 `--section-color` de `grocery_items.css` : troisième palette complète, non
  générée, non documentée. C'est le prochain candidat à la méthode des couleurs de
  jour, après le temps B des régimes. Pas maintenant.

---

## LOT 1 — Police

### 1.1 Le conflit avec l'existant, et sa résolution

`variables.css:124-127` documente le choix de la pile système : « rendu natif sur
chaque OS, sans requête réseau ni FOUT. Choix le plus robuste pour une PWA
offline-first (aucun asset à précacher). » C'est un arbitrage d'architecture, pas
une préférence.

Ajouter une police custom le remet en cause sur deux points, dont un seul est réel.

**Le FOUT.** `font-display: swap` provoque exactement le flash qu'on a voulu éviter.
Pour une PWA, la bonne valeur est **`font-display: optional`** : le navigateur
n'attend jamais la police. Premier chargement en police système, mise en cache ;
à toutes les visites suivantes — le cas normal d'une PWA installée — elle est
disponible immédiatement, sans flash. On obtient l'identité typographique et zéro
FOUT.

**Le precache.** Celui-là est un vrai coût : ~110 Ko pour la variable Fraunces.
D'où le découpage ci-dessous : Fraunces seule d'abord.

### 1.2 Ordre d'opérations impératif

Le rapport de reconnaissance a établi que `install` fait `cache.addAll(PRECACHE_URLS)`,
donc **une seule URL en 404 fait échouer l'installation du service worker entier.**
Un mauvais chemin de police ne casse pas la police : il casse la PWA.

L'ordre n'est donc pas négociable :

```
1. créer app/assets/fonts/ et y déposer le .woff2
2. ajouter link_tree ../fonts dans app/assets/config/manifest.js
3. déclarer @font-face avec une URL que Sprockets sait résoudre  (voir 1.4)
4. redémarrer, PROUVER que l'URL générée répond 200
5. seulement alors : ajouter l'URL à precache_urls
```

Ne pas bumper `sw_revision` : `cache_version` inclut `precache_urls.join`, donc
l'ajout d'une URL fait tourner le cache tout seul. `sw_revision` est réservé aux
changements de stratégie.

Rien à changer côté `fetch` : la classification est par extension sous `/assets/`,
un `.woff2` tombe déjà en cache-first.

### 1.3 Auto-hébergement obligatoire

Pas de CDN Google. Deux raisons : un appel tiers ajoute résolution DNS, négociation
TLS et requête bloquante avant le premier rendu — incompatible avec l'esprit
offline-first ; et embarquer Google Fonts depuis le CDN transmet l'IP du visiteur à
Google, ce qu'un tribunal allemand a jugé contraire au RGPD en janvier 2022
(LG München I, 3 O 17493/20). Ce jugement ne fait pas jurisprudence partout et je
ne suis pas juriste, mais l'auto-hébergement supprime la question tout en étant de
toute façon la meilleure option technique.

Récupération : interroger l'API CSS2 de Google avec un User-Agent moderne renvoie
des URLs `fonts.gstatic.com` pointant sur les `.woff2` variables. Vérifier que
`latin` et `latin-ext` sont couverts (é è ê à ç ù î ï ô œ).

```
Fraunces  variable — axes : opsz 9-144, wght 100-900, SOFT 0-100, WONK 0-1
```

### 1.4 Le piège Sprockets : `.css` n'est pas `.scss`

Les feuilles du projet sont en `.css`. En Sprockets 4, un fichier `.css` **ne passe
par aucun préprocesseur** : un `url('fraunces-variable.woff2')` n'y sera pas
réécrit vers le chemin digéré, et la police ne se chargera pas — ou se chargera
en développement et pas en production, ce qui est pire.

Deux routes viables, à trancher en vérifiant laquelle produit une URL qui répond :

- **`fonts.css.erb`** dans `app/assets/stylesheets/`, avec
  `src: url('<%= asset_path("fraunces-variable.woff2") %>')`. Sprockets traite
  l'extension `.erb`. Attention : le manifeste déclare `link_directory ../stylesheets .css`,
  vérifier que le `.css.erb` est bien pris.
- **`fonts.scss`**, avec `font-url()` ou `asset-url()` fournis par sassc-rails.

Dans les deux cas, ajouter le nouveau fichier au manifeste `application.css`, en
tête — avant `variables` de préférence, la déclaration `@font-face` n'ayant aucune
dépendance.

```css
@font-face {
  font-family: 'Fraunces';
  src: url(/* voir ci-dessus */) format('woff2');
  font-weight: 100 900;
  font-style: normal;
  font-display: optional;
}
```

Token, nommé pour rester cohérent avec `--font-sans` :

```css
--font-serif: 'Fraunces', Georgia, 'Times New Roman', serif;
```

### 1.5 Ne pas faire

**Pas de `<link rel="preload">`.** Le preload force un téléchargement en priorité
haute, ce qui contredit `font-display: optional` : il consomme de la bande passante
critique pour une police qui, par définition, ne servira pas au premier rendu.

### 1.6 Étapes différées

DM Mono (2 fichiers statiques, ~35 Ko) et Instrument Sans sur le corps de texte :
à décider après avoir vu Fraunces en place. Ne pas les installer dans ce lot.

### Critère de validation du LOT 1

Aucune requête vers `fonts.gstatic.com`. L'URL de la police répond 200 en
développement **et** avec les assets précompilés. Le service worker s'installe
sans erreur. Premier chargement : texte visible immédiatement. Second chargement :
titres en Fraunces, sans flash.

---

## LOT 3 — Typographie

### 3.1 Audit de spécificité avant toute écriture

`global.css:32-35` déclare `h1 { font-size: var(--font-size-h1); line-height: 1.2; }`
avec un commentaire explicite : « les classes de titre existantes gardent la main ».
Spécificité 0,0,1. Et `menus.css` / `recipes.css` sont en fin de cascade, donc
gagnants à spécificité égale.

Conséquence : **ajouter `font-family: var(--font-serif)` sur un `h1` nu ne suffira
pas.** Toutes les classes de titre existantes garderont la pile système, et le
résultat sera Fraunces sur certains titres et pas d'autres, sans raison apparente.

Première tâche du lot, avant de coder :

```
Liste toutes les règles CSS qui définissent font-family sur un titre ou une
classe de titre, dans tous les fichiers, avec leur spécificité et leur position
dans la cascade. Indique lesquelles gagnent contre la règle h1 de global.css.
```

Puis décider avec Caroline : soit ajouter `font-family` sur chaque classe de titre
concernée, soit introduire une classe utilitaire explicite. **Pas de `!important`.**

### 3.2 Ne pas créer de seconde échelle

`variables.css` déclare une échelle complète, documentée comme source unique de
vérité : `--font-size-xs` à `--font-size-4xl`, plus `--font-size-h1` fluide, dont
`global.css:32` est l'unique consommateur.

Ce lot **consomme** cette échelle. Aucun token `--text-*`, aucune taille en dur :
ce serait le doublon que le commentaire interdit.

### 3.3 L'axe `opsz` de Fraunces — le piège à connaître

Fraunces a un axe de taille optique. Par défaut, `font-optical-sizing: auto` fait
que le navigateur l'ajuste selon `font-size` : empattements plus fins et contraste
plus élevé sur les grands titres, formes plus robustes en petit. C'est gratuit et
correct.

**Dès qu'on écrit `font-variation-settings`, ce réglage automatique est écrasé.**
En n'y mentionnant que `SOFT` et `WONK`, `opsz` retombe à sa valeur par défaut et
les gros titres deviennent mous. Donc : toujours inclure `opsz`, avec une valeur
proche de la taille en px.

### 3.4 Application

```css
h1, h2, h3 {
  font-family: var(--font-serif);
  font-weight: 500;
}

h1 {
  /* font-size et line-height restent définis par global.css:32-35 */
  letter-spacing: -0.015em;
  font-variation-settings: 'opsz' 30, 'SOFT' 40, 'WONK' 1;
}

h2 {
  font-size: var(--font-size-2xl);
  line-height: 1.2;
  letter-spacing: -0.01em;
  font-variation-settings: 'opsz' 24, 'SOFT' 40, 'WONK' 1;
}

h3 {
  font-size: var(--font-size-xl);
  line-height: 1.3;
  font-variation-settings: 'opsz' 20, 'SOFT' 40, 'WONK' 0;
}
```

`WONK 1` sur h1 et h2, `WONK 0` sur h3 : l'axe fantaisiste est charmant sur un
grand titre unique, agaçant répété sur douze titres de cartes. À regarder en vrai
et à passer à 0 partout si c'est trop.

Le `line-height: 1.2` existant de `global.css` est conservé. Un serif display
supporte un interlignage un peu plus serré (1.12), mais c'est un ajustement à
faire les yeux sur l'écran, pas à l'aveugle dans ce lot.

### 3.5 Périmètre

`--font-serif` **uniquement** sur les titres. Pas sur les labels de formulaire, les
boutons, les libellés d'inputs : un serif dans un champ de saisie ralentit la
lecture et fait « site vitrine » au milieu d'un outil.

`--font-mono`, quand DM Mono sera installé : durées, quantités, nombre de
personnes, nombre de repas, dates. Nulle part ailleurs.

### 3.6 Le plafond de `--font-size-h1`

`clamp(1.25rem, 1rem + 1.1vw, var(--font-size-3xl))` plafonne à 30px. Bien calibré
pour un titre en sans, court pour un display serif dans un bandeau.

**Ne pas y toucher dans ce lot** : `global.css:32` est son unique consommateur, donc
tous les titres de page de l'app en dépendent. Si le titre du hero doit grandir, ce
sera un token dédié au hero, décidé au LOT 4.

### Critère de validation du LOT 3

Fraunces s'applique à **tous** les titres, y compris ceux portant une classe de
`menus.css` et `recipes.css`. Aucun `!important` ajouté. Aucun nouveau token de
taille. Chaque `font-variation-settings` contient `opsz`.

---

## LOT 4 — Hero : deux variantes, une primitive

### 4.1 Pourquoi deux variantes

`home/index.html.haml` sert deux publics via deux partials mutuellement exclusifs,
et ils ont des objectifs opposés :

| | `_vitrine` (visiteur) | `_dashboard` (membre) |
|---|---|---|
| Objectif | convaincre de s'inscrire | agir sur son menu |
| Rôle de la photo | c'est l'argument, elle doit se voir | texture d'ambiance |
| Hauteur | généreuse | contenue |
| Ce qui suit | de la persuasion | une carte actionnable |

Une landing page et un tableau de bord ne se règlent pas avec un modificateur CSS.
Mais les deux partagent la même **mécanique** — pleine largeur, image en `cover`,
voile par-dessus, texte dans le conteneur — et c'est justement la partie pénible à
écrire correctement, donc celle qu'on ne veut pas écrire deux fois avec des
différences subtiles.

D'où : une primitive commune pour la mécanique, deux variantes pour l'éditorial.

### 4.2 La primitive commune

```css
/* home.css — mécanique partagée, aucune décision esthétique ici */
.media-band {
  position: relative;
  display: flex;
  overflow: hidden;
}

.media-band__media {
  position: absolute;
  inset: 0;
  width: 100%;
  height: 100%;
  object-fit: cover;
}

.media-band__scrim {
  position: absolute;
  inset: 0;
}

.media-band__content {
  position: relative;
  width: 100%;
}
```

Quatre règles, zéro couleur, zéro hauteur, zéro alignement. Tout ce qui décide est
dans les variantes.

**Sur le pleine largeur.** Si la home est enveloppée dans un conteneur à
`max-width`, sortir le bandeau de ce conteneur dans le HAML plutôt que compenser en
CSS avec `width: 100vw` et une marge négative : cette technique casse dès qu'une
barre de défilement verticale est présente, parce que `100vw` l'inclut alors que la
largeur disponible non.

**Coquille à corriger au passage.** `home.css:469` référence `var(--font-size-s)`,
qui n'existe pas — la coquille de `--font-size-sm`. La déclaration est invalide,
donc l'élément hérite silencieusement de la taille parente. Ce lot ouvre `home.css` :
autant la corriger ici.

**Sur le header sticky.** Le bandeau se place dans le flux, après le header. Ne pas
compenser `--header-height` à la main, et ne pas ajouter de `env(safe-area-inset-top)` :
le header le porte déjà dans son padding, la zone sûre est incluse dans la hauteur
que `sticky_header_controller` publie. Vérifier qu'aucune règle existante de
`home.css` n'applique déjà un `margin-top` ou `padding-top` calculé sur
`--header-height` au premier bloc.

### 4.3 Variante dashboard — spécifiée

C'est la page vue en capture, donc entièrement spécifiable.

**Ce qui disparaît :**
- Le logo dans le hero. Il est déjà dans la navbar ; deux fois au-dessus de la ligne
  de flottaison, c'est de la répétition, pas de l'emphase.
- Le dégradé latéral de l'image actuelle. C'est ce qui fait lire la page comme un
  bug plutôt que comme un choix.
- Le centrage du texte. Passage en aligné à gauche, sur la même grille que le
  contenu en dessous : un texte centré au-dessus d'un contenu aligné à gauche crée
  deux axes de lecture concurrents.

```css
.home-hero { height: clamp(180px, 26vw, 240px); align-items: center; }

.home-hero .media-band__scrim { background: rgba(28, 25, 22, 0.90); }

.home-hero__title    { color: #F7F2ED; max-width: 34ch; }
.home-hero__subtitle { color: var(--color-ink-on-dark); font-family: var(--font-sans); }
```

Aujourd'hui la carte du menu commence à 415px ; après, ~300px.

**Pourquoi 90%.** Le voile doit garantir le contraste du texte dans le pire cas,
c'est-à-dire au-dessus de la zone la plus claire de la photo (pire cas retenu :
blanc pur). Au-delà de ce plancher, c'est esthétique.

| Opacité | Fond composé | Titre `#F7F2ED` | Sous-titre `#D5CEC6` |
|---|---|---|---|
| 60% | `#777573` | 3,84:1 ✗ | — |
| 68% | `#656361` | 5,38:1 ✓ | 3,81:1 ✗ |
| 72% | `#5C5957` | 6,25:1 ✓ | 4,42:1 — limite |
| **90%** | `#33302D` | **11,79:1 ✓** | **8,41:1 ✓** |

Le plancher est franchement dépassé, ce qui a une conséquence utile : le sous-titre
peut consommer `--color-ink-on-dark`, un token existant, au lieu d'un hex en dur
choisi pour tenir le 4,5:1.

**Ce qu'implique 90%.** La photo ne subsiste qu'à l'état de trace : le contraste
interne entre sa zone la plus claire et la plus sombre passe de 2,36:1 à 72% à
**1,31:1 à 90%**. On perçoit une variation de matière, pas un sujet. C'est le
registre du bandeau de titre, et c'est assumé — mais ça veut dire qu'une image plus
petite et plus légère produira le même effet, puisque le détail est écrasé. Divise
sa résolution, ce qui allège d'autant le precache.

### 4.4 Variante vitrine — paramètres, pas spécification

**Cette page n'a pas été vue.** Ce qui suit sont des paramètres et des contraintes
vérifiées, pas une maquette. Première tâche du lot :

```
Montre-moi la structure HAML de _vitrine et les règles home.css qui la stylent,
avant toute modification.
```

**Le voile plat ne fonctionne pas ici.** Si la photo doit rester visible (~50%), le
pire cas donne 3,01:1 pour un titre clair — échec. Mesuré :

| Voile plat | Fond composé | Titre `#F7F2ED` |
|---|---|---|
| 45% | `#999896` | 2,59:1 ✗ |
| 50% | `#8E8C8A` | 3,01:1 ✗ |
| 55% | `#82807F` | 3,53:1 ✗ |

**La solution est un voile directionnel :** transparent en haut, où la photo
s'exprime et où aucun texte n'est posé ; sombre en bas, où le texte se trouve.

```css
.vitrine-hero { height: clamp(360px, 52vw, 520px); align-items: flex-end; }

.vitrine-hero .media-band__scrim {
  background: linear-gradient(
    to bottom,
    rgba(28, 25, 22, 0.15) 0%,
    rgba(28, 25, 22, 0.45) 45%,
    rgba(28, 25, 22, 0.85) 100%
  );
}
```

Contrastes dans la zone de texte (alpha 0,85, pire cas photo blanche, fond composé
`#3E3C39`) : titre `#F7F2ED` = 9,88:1 · sous-titre `#D5CEC6` = 7,05:1. Et dans la
zone haute (alpha 0,15), la photo reste quasi intacte.

**Le CTA ne peut pas réutiliser `.btn--primary`.** Mesuré : anthracite `#1C1916` sur
le voile sombre donne **1,57:1** — invisible. Le bouton de la vitrine doit être un
aplat clair à texte anthracite :

```css
.btn--on-media {
  background: #F7F2ED;
  color: var(--color-ink);   /* 15,73:1 */
  border-color: transparent;
}
```

**Deux points à trancher devant la page :**
- Le titre. La vitrine porte une proposition de valeur, pas une salutation, et 30px
  y sera probablement insuffisant. C'est ici, et pas au LOT 3, qu'un
  `--font-size-hero` se justifie : `clamp(1.75rem, 1.25rem + 2vw, var(--font-size-4xl))`,
  consommé uniquement par `.vitrine-hero__title`.
- Le logo. Il est déjà dans `.auth-header`, donc en principe redondant dans le
  hero. À confirmer en voyant la page : si l'`auth-header` est plus discret que la
  navbar connectée, l'argument tombe.

### Critère de validation du LOT 4

`.media-band` ne contient aucune couleur, hauteur ou alignement. Les deux variantes
ne dupliquent aucune règle de positionnement. Sur le dashboard, le titre reste
lisible quelle que soit la zone de la photo. Sur la vitrine, la photo est visible
dans sa partie haute et le texte lisible dans sa partie basse. Aucune régression du
comportement sticky du header, dans les deux branches.

---

## LOT 5 — Sémantique et finitions

### 5.1 Répartition des rôles colorés

| Élément | Avant | Après |
|---|---|---|
| Boutons d'action | anthracite | **anthracite — inchangé** |
| Badge « À revalider » | ambre, accent ou warning (ambigu) | `warning` orange |
| Highlights de marque | ambre | `accent` ambre |
| CTA sur média (vitrine) | — | `.btn--on-media` |
| Chip de régime sélectionné | `--color-diet-selected` | `--color-brand` ou `--diet-accent` |
| Suppressions | `danger` | `danger` — inchangé |

### 5.2 `--color-ink-4` : usage restreint

`#A9A29A` sur `#F0EAE3` donne 2,27:1, **en dessous du seuil pour du texte** — y
compris pour un placeholder, qui doit rester lisible.

Ce grep manquait à la reconnaissance, il est donc la première tâche du lot :

```
Liste tous les usages de --color-ink-4, en séparant "sur du texte" et
"décoratif" (bordure, icône, séparateur, état désactivé). Ne remplace rien
avant que j'aie vu la liste.
```

Sur du texte : remplacer par `--color-ink-3`. Garder `ink-4` pour le décoratif.

### 5.3 Cohérence des rayons

`--radius-input: 10px` contre `--radius-button: 4px` : dans un formulaire, le champ
est plus arrondi que le bouton qui le valide, et ça se voit. Soit descendre l'input
vers 6px pour s'aligner sur `--radius-card`, soit assumer le contraste comme parti
pris. À trancher, mais pas à laisser au hasard.

### 5.3 bis Anneau de focus supprimé par une dizaine de composants

Le LOT 2.8 a rendu le token correct, mais une dizaine de règles
`…:focus { outline: none }` dans `recipes.css`, `menus.css`, `tags.css` et
`ingredients.css` **gagnent** contre le `:focus-visible` global — à spécificité
égale, ces feuilles passent après `global.css`. Ces composants ne laissent qu'un
changement de `border-color` comme indicateur de focus clavier : visible, mais
nettement plus faible qu'un contour de 2px.

Un anneau de focus qu'une douzaine de composants suppriment est un anneau de focus
qui n'existe pas. Reprendre le recensement fait au 2.8 et, pour chaque cas, soit
supprimer le `outline: none`, soit vérifier que l'alternative atteint 3:1 contre le
fond adjacent.

### 5.4 Troncature des titres de cartes

« Tartelette au chèvre sur... » et « Poulet Rôti aux Herbes de... » coupent en
milieu de syntagme. Deux lignes complètes :

```css
.mc-card-name-wrap .recipe-title {  /* nom de classe à confirmer dans le partial */
  display: -webkit-box;
  -webkit-line-clamp: 2;
  -webkit-box-orient: vertical;
  overflow: hidden;
  text-wrap: pretty;
}
```

À appliquer dans les **deux** partials : `_menu_recipe_card.html.haml` et
`_menu_recipe_card_readonly.html.haml`.

### 5.5 Casse des titres de recettes

« Poulet Rôti aux Herbes de Provence » : la capitale à chaque mot est une convention
anglaise. En français, seule la première lettre et les noms propres → « Poulet rôti
aux herbes de Provence ». À corriger dans les données, pas en CSS.

---

## HORS PÉRIMÈTRE

- **Ne pas toucher au logo.** Il est la source de vérité de la palette.
- **Ne pas migrer vers Tailwind.** Le système de custom properties fonctionne.
- **Pas de mode sombre.** Les tokens `--color-surface-dark-*` servent une carte
  sombre spécifique, pas un thème — la documentation du projet le dit. Ne pas les
  traiter comme l'amorce d'un dark mode.
- **Ne pas toucher aux couleurs de jour** de `menus.css`. Elles sont le modèle, pas
  la cible.
- **Ne pas récupérer la palette du prototype** (`#FF5A1F`, `#5646E0`, Bricolage
  Grotesque). Abandonnée.
- **Aucun `!important`** ajouté, dans aucun lot.
- **Ne pas refactorer la navbar.** Elle est dupliquée en deux branches dans le
  layout ; c'est une dette réelle, mais c'est un autre chantier.

---

## NOTES MINEURES — à signaler, pas à corriger

Constats qui ne relèvent d'aucun lot. À vérifier un jour, séparément.

- **Les liens sont plus clairs que le texte qui les entoure.** `global.css` pose
  `a { color: var(--color-ink-3); }` alors que le `body` est en `--color-ink-2`.
  Contraste entre les deux : 1,77:1 aujourd'hui, 1,53:1 après le LOT 2. Sous 3:1,
  deux couleurs de texte ne se distinguent pas de façon fiable — et ici la
  distinction va dans le sens contre-intuitif, le lien paraissant moins important
  que la phrase. Sans soulignement, un lien en pleine prose n'est donc identifiable
  par presque rien. Le commentaire du fichier indique que l'affordance passe par le
  survol et que les composants gèrent le leur, donc l'impact réel dépend du nombre
  de liens nus dans du texte courant. À mesurer avant de trancher.
- **Quatre `var()` pointent dans le vide** : `--font-size-s` (`home.css:469`,
  coquille de `-sm`, corrigé au LOT 4), `--icon-color-1`, `--icon-color-2` et
  `--mc-card-height`. Un `var()` non résolu **échoue silencieusement** : la
  propriété retombe sur sa valeur héritée ou initiale, sans erreur console. C'est le
  type de bug qui survit des années. Deux autres cas (`--success-border`,
  `--error-border`) ont été corrigés au LOT 2.12.
- **Heuristique de revue à ajouter au `CLAUDE.md`** : une règle CSS qui mélange un
  `var()` et une couleur en dur est un endroit tokenisé à moitié, donc un endroit qui
  divergera au prochain changement de token. Les deux seuls composants cassés par le
  LOT 2 étaient exactement les deux règles de ce type.
- `authentication.css` est à la fois dans le bundle `application.css` et précompilé
  à part (`config/initializers/assets.rb:15`). Si la version autonome n'est chargée
  par aucun layout, l'entrée de precompile est de la configuration morte.
- La navbar écrite en dur en deux branches complètes dans le layout : toute
  évolution de nav se fait à deux endroits, avec le risque de divergence habituel.
- `sw_revision` est à `"r8"` avec un historique commenté. Bonne pratique, rien à
  faire, mais utile à connaître avant d'y toucher.

---

## DÉCISIONS OUVERTES

| Sujet | Où | À décider |
|---|---|---|
| `--font-size-hero` | LOT 4.4 | devant la vitrine |
| Logo dans le hero vitrine | LOT 4.4 | devant la vitrine |
| `line-height` des h1 à 1,12 | LOT 3.4 | après installation de Fraunces |
| `WONK` à 1 ou 0 | LOT 3.4 | à l'œil |
| `--radius-input` 10px vs 6px | LOT 5.3 | à l'œil |
| DM Mono | LOT 1.6 | après Fraunces |
| Instrument Sans sur le corps | LOT 1.6 | après Fraunces |
| Garder ou supprimer la photo du dashboard | LOT 4.3 | devant la maquette |

---

## UNE REMARQUE POUR FINIR

Fond crème chaud + display serif + accent chaud est une combinaison très répandue
en ce moment. Ici elle est justifiée — le crème vient de l'unification de ta propre
rampe, l'ambre de ta charte existante — mais elle ne différenciera pas EasyMeal à
elle seule.

Ce qui le fera, c'est un élément signature. Il y en a déjà deux amorcés : les
couleurs de jour générées en OKLCH sur la grille menu, et la casserole dessinée du
logo. Concentre l'audace là, et garde tout le reste discipliné.
