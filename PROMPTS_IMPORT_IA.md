# Import IA de recettes — prompts à envoyer un par un

Issu de l'analyse du 11/08/2026 du flux d'import (lien internet + photo) : vues
`recipe_drafts` / `recipe_imports`, contrôleurs, `Recipes::ExtractorService`.

## Mode d'emploi

Envoie **un seul prompt à la fois**, dans l'ordre. Chaque prompt est autonome :
copie-colle le bloc « Prompt à envoyer » tel quel.

Après chaque étape :

1. Je relance les RSpec indiqués.
2. Tu fais les vérifications visuelles listées.
3. **Tu commites toi-même** avec le nom proposé (je ne commite jamais).

Rappels d'environnement :

- Ruby/Rails tournent **uniquement dans WSL** (`cd /mnt/c/Caroline/easymeal`).
- Git se fait en **PowerShell**.
- Baseline RSpec : la suite doit rester 100 % verte. Note le nombre d'exemples
  avant de commencer — tout échec est une vraie régression.

**Coordination avec PROMPTS_REFACTORING.md** : les étapes 10 à 12 de ce fichier
(tests de caractérisation puis découpage d'`ExtractorService`) sont le meilleur
préalable aux étapes 6 et 7 d'ici, qui modifient le cœur du service. Fais-les
d'abord si possible. Les prompts 5, 6 et 7 précisent quand même quoi faire si le
découpage n'a pas encore eu lieu — rien ne casse, seuls les noms de fichiers
changent.

Ordre voulu : d'abord le **design** (étapes 1 à 4, indépendantes entre elles),
puis la **robustesse** (étape 5), puis le **chantier IA** (étapes 6 et 7, dans
cet ordre), et enfin le **confort de validation** (étape 8).

---

# Étape 1 — Liste des brouillons : badge « Lien » cliquable et cartes élargies

> Deux irritants sur `/recipe_drafts` : le badge « Lien » n'emmène nulle part
> alors que l'URL d'origine est en base, et les noms de recettes longs sont
> tronqués par une ellipsis dans des cartes limitées à 820 px.

- **Modèle conseillé** : Sonnet — effort faible (une vue, un helper, du CSS)

### Prompt à envoyer

```
**Qualité non négociable** : code simple, refactorisé, DRY, bien commenté, fiable, robuste, zéro code mort, bonnes pratiques Rails/Hotwire/HAML et conventions du projet.

Contexte : sur la liste des recettes importées (/recipe_drafts), chaque carte
affiche un badge de source (« Lien » ou « Photo »). Pour les imports par URL,
recipe.source_url est stocké en base mais le badge est un simple span : on ne
peut pas ouvrir la page d'origine pour comparer pendant la validation. Par
ailleurs les cartes vivent dans .rf-body (max-width: 820px) et le nom est en
white-space: nowrap + text-overflow: ellipsis : les titres un peu longs sont
coupés alors que l'écran a de la place.

Fichiers de contexte :
- app/views/recipe_drafts/index.html.haml (badge lignes 39-42, carte entière)
- app/assets/stylesheets/recipes.css (bloc draft-* lignes ~3860-4078, .rf-body
  ligne ~2630, .rf-hero-inner ligne ~2594)
- app/helpers/recipes_helper.rb (draft_source_label / draft_source_icon)
- db/schema.rb (recipes.source_url est un string, nullable)

Demandes :
1. Badge « Lien » : quand source_type == "url" ET source_url est présent, rends
   le badge cliquable — un lien vers source_url, target: "_blank",
   rel: "noopener noreferrer", avec un title qui annonce l'ouverture de la page
   d'origine. Ajoute un état :hover discret (souligné ou bordure) pour signaler
   l'interactivité, dans la charte existante. Les autres cas (photo, ou vieux
   brouillon URL sans source_url) gardent le span actuel.
2. Attention au clic : la carte n'est pas cliquable en entier, mais vérifie que
   le lien n'entre pas en conflit avec les boutons d'action existants.
3. Cartes plus larges : n'élargis PAS .rf-body globalement (il est partagé par
   toutes les pages recettes). Crée un modificateur (par exemple .rf-body--wide,
   max-width ~1080px) appliqué uniquement sur la page des brouillons, et applique
   la même largeur au hero de cette page pour garder la colonne alignée.
4. Nom de recette : remplace la troncature sur une ligne par un affichage sur
   2 lignes maximum (line-clamp), l'ellipsis ne servant que de garde-fou au-delà.
   Vérifie le rendu responsive (le media query existant passe déjà la carte en
   colonne et le nom en white-space: normal).
```

### RSpec

À relancer :

```bash
cd /mnt/c/Caroline/easymeal && bundle exec rspec spec/requests/recipe_drafts_spec.rb && bundle exec rspec
```

Si le spec vérifie le HTML du badge, ajoute un exemple : un brouillon importé par
URL rend un lien `target="_blank"` vers sa source_url ; un brouillon photo n'en
rend pas.

### Vérification de ton côté

- `/recipe_drafts` avec au moins un import URL : le badge « Lien » ouvre la page
  d'origine dans un nouvel onglet ; au survol, le badge signale qu'il est cliquable.
- Un import photo : badge « Photo » inchangé, non cliquable.
- Les cartes occupent une colonne plus large, alignée avec le titre de la page ;
  un nom long s'affiche sur deux lignes au lieu d'être coupé.
- Réduis la fenêtre en largeur téléphone : la carte passe en colonne comme avant,
  rien ne déborde.

### Ce que ça fait

Le badge devient un vrai lien hypertexte : pendant la validation d'un brouillon,
tu peux rouvrir la recette d'origine pour comparer. Et la liste respire : la
colonne s'élargit uniquement sur cette page (les autres pages recettes gardent
leur largeur), le nom a droit à deux lignes avant d'être tronqué.

### Commit proposé

`badge source cliquable et cartes élargies sur la liste des brouillons`

---

# Étape 2 — Page d'import : glisser-déposer et collage direct

> La zone photo n'accepte que le clic ; le formulaire de recette a pourtant déjà
> une vraie dropzone. Et le cas d'usage le plus fréquent — une capture d'écran
> ou une URL dans le presse-papiers — mérite un simple Ctrl+V.

- **Modèle conseillé** : Opus — effort moyen (Stimulus, presse-papiers, cohérence avec la dropzone existante)

### Prompt à envoyer

```
**Qualité non négociable** : code simple, refactorisé, DRY, bien commenté, fiable, robuste, zéro code mort, bonnes pratiques Rails/Hotwire/HAML et conventions du projet.

Contexte : sur /recipe_imports/new, la zone photo (.import-file-zone) n'accepte
que le clic, alors que le formulaire de recette possède déjà une dropzone avec
glisser-déposer (rf-dropzone + image_preview_controller). Par ailleurs, le
parcours réel de l'utilisatrice passe souvent par le presse-papiers : une URL
copiée depuis le navigateur, ou une capture d'écran d'une recette vue sur un
réseau social. Aujourd'hui il faut cliquer au bon endroit ; l'objectif est que
« coller » fasse le bon choix tout seul.

Fichiers de contexte :
- app/views/recipe_imports/new.html.haml
- app/javascript/controllers/import_source_controller.js
- app/javascript/controllers/image_preview_controller.js (pour reprendre le
  langage visuel et le pattern dragover/drop existants — sans fusionner les
  deux contrôleurs, leurs responsabilités sont différentes)
- app/assets/stylesheets/recipes.css (bloc import-* à partir de ~4080, et le
  style .rf-dropzone pour l'état "survol de dépôt")
- spec/requests/recipe_imports_spec.rb (des assertions portent sur le HTML de
  la page — mets-les à jour si la structure change)

Demandes :
1. Glisser-déposer sur la zone photo : dragover/dragleave/drop, avec un état
   visuel de survol cohérent avec la dropzone du formulaire de recette. Un
   fichier déposé suit exactement le même chemin que la sélection au clic
   (aperçu, nom du fichier, garde anti-vide).
2. Collage (Ctrl+V / Cmd+V) n'importe où sur la page d'import :
   - le presse-papiers contient une image → bascule sur l'onglet Photo, injecte
     le fichier dans l'input (DataTransfer) et affiche l'aperçu ;
   - le presse-papiers contient un texte commençant par http(s):// → bascule sur
     l'onglet Lien et remplit le champ URL ;
   - sinon, ne fais rien (ne casse pas le collage normal dans le champ URL).
   Nettoie bien le listener à la déconnexion du contrôleur Stimulus.
3. Ajoute sous chaque section un indice discret qui annonce ces gestes (« ou
   colle une capture d'écran », « tu peux aussi coller l'URL directement »), dans
   le ton et la charte de la page.
4. Ne mets PAS d'attribut capture sur l'input file : sur mobile il forcerait
   l'appareil photo et empêcherait de choisir une image de la galerie — le
   sélecteur natif propose déjà les deux.
5. L'onglet s'appelle « Photo de magazine » alors qu'il sert aussi aux captures
   d'écran : propose-moi un libellé plus englobant (par exemple « Photo ou
   capture ») en respectant la place disponible, et applique-le après m'avoir
   indiqué ton choix.
```

### RSpec

À relancer :

```bash
cd /mnt/c/Caroline/easymeal && bundle exec rspec spec/requests/recipe_imports_spec.rb && bundle exec rspec
```

Le spec existant vérifie la présence des onglets ARIA et de l'aperçu — adapte
ses assertions si des classes ou libellés changent, sans affaiblir ce qu'il teste.

### Vérification de ton côté

- Glisse une image depuis l'Explorateur sur la zone photo → l'aperçu apparaît,
  comme après un clic ; pendant le survol, la zone change d'état visuellement.
- Copie une capture d'écran (Win+Maj+S) puis Ctrl+V sur la page → l'onglet Photo
  s'active tout seul avec l'aperçu.
- Copie une URL de recette puis Ctrl+V → l'onglet Lien s'active, le champ est
  rempli.
- Colle du texte quelconque dans le champ URL → comportement normal d'un collage.
- Soumets ensuite un import complet depuis un fichier déposé : l'extraction doit
  fonctionner comme avant.

### Ce que ça fait

Le geste le plus naturel — copier une recette repérée quelque part, ouvrir la
page d'import, coller — devient le chemin le plus court. Le formulaire détecte
si le presse-papiers contient une image ou un lien et choisit l'onglet à ta
place. Le glisser-déposer aligne cette page sur ce que le formulaire de recette
sait déjà faire.

### Commit proposé

`glisser-déposer et collage direct sur la page d'import IA`

---

# Étape 3 — Redimensionner la photo côté navigateur avant l'envoi

> Une photo de téléphone pèse 5 à 15 Mo. Elle est envoyée telle quelle au
> serveur, puis encodée en base64 vers l'API Claude — upload lent, requête
> énorme, tokens image gaspillés, et risque de rejet (l'API refuse les images
> trop lourdes).

- **Modèle conseillé** : Opus — effort moyen (canvas, remplacement du fichier dans l'input, cas limites)

### Prompt à envoyer

```
**Qualité non négociable** : code simple, refactorisé, DRY, bien commenté, fiable, robuste, zéro code mort, bonnes pratiques Rails/Hotwire/HAML et conventions du projet.

Contexte : sur /recipe_imports/new, la photo choisie part au serveur sans aucune
réduction, puis RecipeImportsController l'encode en base64 pour l'API Claude.
Une photo de téléphone récente (4000×3000, 5 à 15 Mo) rend l'upload lent, gonfle
la requête API (l'API Anthropic plafonne la taille par image) et coûte des
tokens image pour une précision inutile : pour lire du texte de recette,
~1600 px sur le grand côté suffisent largement. L'objectif est de réduire
l'image côté navigateur, avant l'envoi — aucun changement serveur.

Fichiers de contexte :
- app/javascript/controllers/import_source_controller.js (previewPhoto et la
  gestion du fileInput ; l'étape précédente y a ajouté drop et collage — le
  redimensionnement doit s'appliquer à ces trois chemins d'entrée)
- app/views/recipe_imports/new.html.haml
- app/controllers/recipe_imports_controller.rb (pour vérifier qu'aucun
  changement n'y est nécessaire)

Demandes :
1. À la sélection d'une photo (clic, dépôt ou collage), si l'image dépasse
   ~1600 px sur son grand côté, redessine-la sur un canvas à 1600 px max (ratio
   conservé) et exporte en JPEG qualité ~0.85. Remplace le fichier de l'input
   par le résultat (DataTransfer) pour que le formulaire soumette la version
   réduite. Mutualise le traitement pour les trois chemins d'entrée.
2. L'aperçu et le nom de fichier affichés doivent refléter le fichier réellement
   envoyé (indique le poids final à côté du nom, c'est une bonne réassurance).
3. Robustesse : si le décodage ou le canvas échoue (format exotique, mémoire),
   garde silencieusement le fichier d'origine — le redimensionnement est une
   optimisation, jamais un blocage. Ajoute en revanche un garde-fou dur : au-delà
   de 20 Mo, refuse le fichier avec un message clair via la zone d'erreur
   existante (showError), avant tout envoi.
4. Pas de nouvelle dépendance JavaScript : canvas natif uniquement.
5. Explique-moi en une phrase pourquoi le redimensionnement côté client a été
   préféré à un traitement serveur (image_processing est présent dans le
   Gemfile) — je veux comprendre l'arbitrage.
```

### RSpec

À relancer (aucun changement serveur attendu — la suite confirme) :

```bash
cd /mnt/c/Caroline/easymeal && bundle exec rspec spec/requests/recipe_imports_spec.rb && bundle exec rspec
```

### Vérification de ton côté

- Importe une vraie photo de téléphone (plusieurs Mo) : l'aperçu s'affiche, le
  poids indiqué à côté du nom est de l'ordre de quelques centaines de Ko, et
  l'extraction fonctionne — nettement plus vite qu'avant.
- Importe une petite image (< 1600 px) : elle part telle quelle.
- Dans l'onglet réseau du navigateur (F12), vérifie la taille de la requête
  POST /recipe_imports : elle doit correspondre au fichier réduit.
- Essaie un fichier aberrant (> 20 Mo) : message d'erreur immédiat, pas d'envoi.

### Ce que ça fait

Le navigateur sait redessiner une image sur un canvas et en produire une version
réduite : on s'en sert pour envoyer une photo de ~400 Ko au lieu de 10 Mo. Tout
va plus vite (l'upload, l'appel à l'IA) et coûte moins cher, sans rien installer
sur le serveur. Le garde-fou de 20 Mo évite qu'un fichier énorme parte quand
même si le redimensionnement échoue.

### Commit proposé

`redimensionnement des photos côté navigateur avant import IA`

---

# Étape 4 — Attente honnête et erreur qui ne fait pas tout perdre

> Pendant l'extraction, le bouton affiche un libellé figé pendant 15 à 30 s.
> Et si l'extraction échoue, la page revient vierge : l'URL saisie est perdue.

- **Modèle conseillé** : Sonnet — effort moyen (Stimulus + un paramètre au redirect)

### Prompt à envoyer

```
**Qualité non négociable** : code simple, refactorisé, DRY, bien commenté, fiable, robuste, zéro code mort, bonnes pratiques Rails/Hotwire/HAML et conventions du projet.

Contexte : sur /recipe_imports/new, le submit affiche « Extraction en cours…
(15 à 30 s) » et plus rien ne bouge jusqu'à la réponse. Par ailleurs, quand
l'extraction échoue, RecipeImportsController#create redirige vers
new_recipe_import_path sans paramètre : le champ URL revient vide alors que la
vue sait déjà le pré-remplir (url_field_tag lit params[:source_url]). Perdre
l'URL après 30 s d'attente est le pire moment pour faire ressaisir.

Fichiers de contexte :
- app/javascript/controllers/import_source_controller.js (méthode submit)
- app/views/recipe_imports/new.html.haml (bouton, spinner, notice)
- app/controllers/recipe_imports_controller.rb (les deux redirects d'échec :
  rescue ExtractionError et l'échec de recipe.save)
- spec/requests/recipe_imports_spec.rb

Demandes :
1. Côté serveur : sur les deux chemins d'échec, si source_type vaut "url",
   redirige vers new_recipe_import_path(source_url: params[:source_url]) pour
   que le champ soit pré-rempli au retour. Pour un import photo, le navigateur
   ne peut pas re-remplir un input file : le message d'alerte doit le dire
   simplement (« choisis à nouveau la photo »).
2. Côté client : pendant l'attente, remplace le libellé figé par une rotation de
   messages d'étape honnêtes (pas de fausse barre de progression), par exemple :
   « Lecture de la page… » puis « Extraction par l'IA… » puis « Encore quelques
   secondes… » — adaptés selon la source (photo : « Lecture de la photo… »).
   Toutes les 5-6 secondes environ, via des timers Stimulus proprement nettoyés
   dans disconnect(). Le conteneur du libellé passe en aria-live="polite" pour
   que le changement soit annoncé aux lecteurs d'écran.
3. Garde le spinner et le disabled anti double-clic existants.
4. Ajoute au spec de requêtes un exemple POST /recipe_imports où le service
   d'extraction (mocké) lève ExtractionError : la réponse redirige vers la page
   d'import AVEC le source_url dans l'URL, et le flash d'alerte contient le
   message d'erreur.
```

### RSpec

À relancer :

```bash
cd /mnt/c/Caroline/easymeal && bundle exec rspec spec/requests/recipe_imports_spec.rb && bundle exec rspec
```

### Vérification de ton côté

- Lance un import URL valide : les messages d'étape défilent pendant l'attente,
  puis la redirection vers le formulaire de validation fonctionne comme avant.
- Lance un import avec une URL bidon (`https://exemple-inexistant-12345.fr`) :
  après l'échec, le message d'erreur s'affiche ET le champ URL contient encore
  ton URL — corrige-la et relance sans tout retaper.
- Import photo qui échoue (coupe le Wi-Fi juste après le submit, par exemple) :
  le message invite clairement à rechoisir la photo.

### Ce que ça fait

L'attente devient vivante : des messages d'étape sincères remplacent le libellé
figé — on sait que quelque chose se passe, sans inventer un pourcentage que le
serveur ne connaît pas. Et l'échec ne punit plus : l'URL saisie revient
pré-remplie dans le champ, prête à être corrigée.

### Commit proposé

`messages d'attente progressifs et URL conservée en cas d'échec d'import`

---

# Étape 5 — Robustesse du téléchargement de la page à importer

> Trois failles discrètes dans la récupération HTML : une redirection relative
> fait planter le service, une page énorme est chargée sans limite, et une URL
> qui pointe vers un PDF ou une image part quand même dans le parseur HTML.

- **Modèle conseillé** : Sonnet — effort moyen (Net::HTTP, cas limites à tester)

### Prompt à envoyer

```
**Qualité non négociable** : code simple, refactorisé, DRY, bien commenté, fiable, robuste, zéro code mort, bonnes pratiques Rails/Hotwire/HAML et conventions du projet.

Contexte : le téléchargement de la page à importer (méthode fetch_html — dans
Recipes::PageFetcher si l'étape 11 de PROMPTS_REFACTORING.md est passée, sinon
encore dans Recipes::ExtractorService) a trois faiblesses :
1. Une redirection avec un Location RELATIF (« /recettes/tarte.html », fréquent)
   est repassée telle quelle à URI.parse → Net::HTTP.new(nil, nil) → erreur
   générique au lieu de suivre la redirection.
2. Le corps de la réponse est lu sans plafond : une URL qui renvoie un fichier
   de plusieurs dizaines de Mo est chargée entière en mémoire.
3. Aucune vérification de Content-Type : une URL vers un PDF ou une image part
   dans Nokogiri et produit une erreur confuse en aval.

Fichiers de contexte :
- app/services/recipes/page_fetcher.rb si présent, sinon
  app/services/recipes/extractor_service.rb (méthode fetch_html)
- le spec correspondant s'il existe (spec/services/recipes/page_fetcher_spec.rb
  ou extractor_service_spec.rb)

Demandes :
1. Résous les redirections relatives avec URI.join(url_courante, location)
   avant de suivre — les redirections absolues continuent de fonctionner.
2. Plafonne la taille téléchargée (par exemple 3 Mo) : au-delà, lève
   ExtractionError avec un message français clair (« Cette page est trop
   volumineuse pour être importée »). Explique-moi en une phrase l'approche
   retenue (Content-Length quand il est présent, contrôle de la taille du corps
   sinon, ou lecture en flux).
3. Si le Content-Type de la réponse finale n'est pas du HTML (text/html ou
   application/xhtml+xml), lève ExtractionError avec un message qui oriente
   (« Cette adresse ne pointe pas vers une page de recette — essaie l'adresse
   de la page, pas du fichier »).
4. Couvre les trois comportements par des exemples de spec (WebMock) : une
   redirection relative suivie avec succès, une réponse trop grosse rejetée,
   un Content-Type PDF rejeté.
```

### RSpec

À relancer :

```bash
cd /mnt/c/Caroline/easymeal && bundle exec rspec spec/services && bundle exec rspec
```

### Vérification de ton côté

- Importe une recette d'un site connu (Marmiton, 750g) : rien ne change.
- Importe une URL de PDF (n'importe quel PDF en ligne) : message d'erreur clair,
  pas de page 500 ni de message cryptique.
- Si tu connais une URL courte type bit.ly vers une recette, essaie-la : la
  redirection doit être suivie.

### Ce que ça fait

Le téléchargeur de pages apprend trois politesses du web réel : suivre les
redirections écrites en relatif (très courantes), refuser poliment les fichiers
trop lourds au lieu de saturer la mémoire, et reconnaître qu'un PDF n'est pas
une page web avant d'essayer de le lire comme du HTML.

### Commit proposé

`robustesse du téléchargement de page (redirections relatives, taille, content-type)`

---

# Étape 6 — Gem officiel `anthropic`, Claude Sonnet 5 et sorties structurées

> Le cœur du chantier IA. Trois modernisations solidaires : le SDK officiel
> remplace ~60 lignes de Net::HTTP artisanal, le modèle passe à la génération
> actuelle, et les sorties structurées garantissent le JSON — toute la classe
> d'erreurs « L'IA n'a pas retourné un JSON valide » disparaît par construction.

- **Modèle conseillé** : Opus — effort élevé (SDK à manier correctement, schéma JSON strict, specs à adapter)
- **Prérequis fortement conseillé** : étapes 10 à 12 de PROMPTS_REFACTORING.md
  (le code visé est alors isolé dans Recipes::ClaudeClient et
  Recipes::ClaudePrompts, avec des tests de caractérisation comme filet).

### Prompt à envoyer

```
Commence par charger le skill claude-api, puis exécute ce prompt :

**Qualité non négociable** : code simple, refactorisé, DRY, bien commenté, fiable, robuste, zéro code mort, bonnes pratiques Rails/Hotwire/HAML et conventions du projet.

Contexte : l'extraction de recettes appelle l'API Anthropic en Net::HTTP brut
(le code vit dans Recipes::ClaudeClient et Recipes::ClaudePrompts si le
découpage de PROMPTS_REFACTORING.md étapes 11-12 est fait, sinon dans
Recipes::ExtractorService). Trois problèmes :
1. Le modèle est "claude-sonnet-4-6" : une génération de retard, et surtout il
   ne supporte pas les sorties structurées.
2. La sortie JSON n'est pas garantie : le prompt supplie (« UNIQUEMENT du JSON »),
   le code gratte les balises markdown au gsub, et JSON.parse échoue parfois →
   erreur « L'IA n'a pas retourné un JSON valide » vue par l'utilisatrice.
3. max_tokens: 2048 tronque les recettes longues (beaucoup d'ingrédients et
   d'étapes) → JSON coupé → échec complet de l'import.

Objectif : gem officiel anthropic + modèle "claude-sonnet-5" + sorties
structurées (output_config.format avec un json_schema strict). L'interface
publique (ExtractorService.from_url / .from_photo) et le format du hash
retourné ne changent PAS.

Fichiers de contexte :
- app/services/recipes/extractor_service.rb (et claude_client.rb /
  claude_prompts.rb s'ils existent)
- spec/services/recipes/ (les specs de caractérisation existants)
- spec/requests/recipe_imports_spec.rb
- Gemfile, .env / .env.example (ANTHROPIC_API_KEY)

Demandes :
1. Ajoute le gem officiel "anthropic" (dernière version stable) au Gemfile et
   remplace tout le code Net::HTTP d'appel API par Anthropic::Client. Points
   Ruby à respecter : le paramètre système s'écrit system_ (underscore final),
   le client lit ANTHROPIC_API_KEY tout seul — mais garde une vérification
   explicite de sa présence avec le message d'erreur français actuel.
2. Passe le modèle à "claude-sonnet-5" et max_tokens à 8192.
3. Sorties structurées : définis le schéma JSON de la recette (celui de
   json_schema_example, formalisé) et passe-le via
   output_config: { format: { type: "json_schema", schema: ... } }.
   Contraintes du schéma : additionalProperties: false partout, required
   exhaustifs, enums stricts pour difficulty ("facile"/"moyen"/"difficile" ou
   null), diet (les 4 régimes), unit des ingrédients (g, kg, ml, cl, L, càc,
   càs ou null). Pas de contraintes numériques (non supportées) : les gardes
   Ruby existantes (valid_enum, [x, 1].max) restent en place, c'est la ceinture
   ET les bretelles.
4. L'appel de structuration des ingrédients (chemin schema.org) passe aussi aux
   sorties structurées — la racine d'un schéma étant un objet, enveloppe le
   tableau dans { "ingredients": [...] } et déballe côté Ruby.
5. Supprime ce que les sorties structurées rendent mort : le nettoyage des
   balises markdown (gsub sur ```), et les injonctions « UNIQUEMENT un JSON
   valide » dans le system et les prompts (le format est garanti par l'API, le
   prompt n'a plus à le mendier).
6. Traduis les erreurs du SDK en ExtractionError avec les messages français
   actuels : classes typées Anthropic::Errors (APIStatusError et ses filles
   pour les erreurs HTTP, APIConnectionError pour le réseau), plus le timeout.
   Le SDK réessaie tout seul les 429/5xx (max_retries par défaut) — ne
   réimplémente pas de retry.
7. Les specs existants qui simulaient l'API en Net::HTTP/WebMock doivent être
   adaptés : même endpoint api.anthropic.com/v1/messages, mais vérifie que les
   stubs matchent le nouveau corps de requête (output_config présent) et que
   la réponse simulée reste au format content[0].text. Le nombre total
   d'exemples ne doit pas baisser.
8. Mets à jour le commentaire d'architecture éventuel : plus aucun parsing
   défensif de fences markdown ne doit subsister.
```

### RSpec

À relancer :

```bash
cd /mnt/c/Caroline/easymeal && bundle exec rspec spec/services spec/requests/recipe_imports_spec.rb && bundle exec rspec
```

### Vérification de ton côté

- Importe une URL **avec** schema.org (Marmiton) : pré-remplissage complet,
  ingrédients structurés.
- Importe une URL **sans** schema.org (un blog) : le chemin « texte → IA »
  fonctionne.
- Importe une **photo** de recette : extraction OK.
- Importe une recette **longue** (type paella, 15+ ingrédients) : c'est le cas
  que max_tokens: 2048 faisait échouer — il doit passer.
- Test d'erreur : vide ANTHROPIC_API_KEY dans .env, relance le serveur, tente un
  import → message français clair mentionnant la variable, pas de page 500.
  Remets la clé ensuite.

### Ce que ça fait

Trois mises à niveau qui se renforcent. Le gem officiel remplace la plomberie
HTTP maison (et réessaie tout seul quand l'API est momentanément surchargée).
Le modèle passe à la génération actuelle, meilleure en extraction. Et les
« sorties structurées » sont un contrat : on fournit à l'API le schéma exact du
JSON attendu, elle garantit que la réponse s'y conforme — le code n'a plus à
supplier, gratter ni vérifier, et l'erreur « JSON invalide » ne peut plus se
produire. Le plafond de tokens élargi règle l'échec des recettes longues.

### Commit proposé

`extraction IA : gem anthropic, Claude Sonnet 5 et sorties structurées`

---

# Étape 7 — L'IA pré-coche moments du repas, budget et tags

> La réponse à « est-ce que l'IA pourrait suggérer les tags pour qu'ils soient
> déjà cochés ? » : oui. Difficulté et régime sont déjà pré-remplis ; on ajoute
> les moments du repas, le budget et les tags du catalogue — le formulaire de
> validation les affichera cochés, à toi de confirmer ou corriger.

- **Modèle conseillé** : Opus — effort élevé (prompt IA, schéma, mapping contrôleur, règles métier des régimes)
- **Prérequis** : étape 6 (le schéma structuré est le support naturel de ces champs).

### Prompt à envoyer

```
Commence par charger le skill claude-api, puis exécute ce prompt :

**Qualité non négociable** : code simple, refactorisé, DRY, bien commenté, fiable, robuste, zéro code mort, bonnes pratiques Rails/Hotwire/HAML et conventions du projet.

Contexte : l'extraction IA remplit déjà difficulty et diet, mais le formulaire
de validation d'un brouillon présente trois autres classements que
l'utilisatrice doit cocher à la main : les moments du repas (obligatoires pour
publier — MealTypes::MEAL_TYPES), le budget (enum price : economique / moyen /
cher) et les tags du catalogue (table tags, groupés par type). L'IA doit les
suggérer pour qu'ils arrivent PRÉ-COCHÉS dans le formulaire — la validation
humaine reste le garde-fou. À noter : extract_from_schema produit un
"suggested_tags" (recipeCategory) stocké dans ai_raw_data mais jamais exploité
— cette étape le remplace par de vraies suggestions appliquées.

Fichiers de contexte :
- app/services/recipes/ (extractor_service.rb + claude_prompts.rb /
  schema_org_parser.rb s'ils existent) — le schéma JSON et les prompts de
  l'étape précédente
- app/controllers/recipe_imports_controller.rb (build_draft_recipe, valid_enum)
- app/models/concerns/meal_types.rb et has_meal_types.rb (vocabulaire fermé)
- app/models/tag.rb (Tag.grouped_by_type, TAG_TYPE_LABELS)
- app/models/recipe.rb (enum price, DIET_COMPATIBILITY)
- app/views/recipes/_form.html.haml (les segmented_field et les checkboxes de
  tags lisent le modèle : AUCUN changement de vue ne devrait être nécessaire —
  vérifie-le)
- spec/requests/recipe_imports_spec.rb

Demandes :
1. Étends le schéma JSON structuré avec :
   - "meal_types" : tableau d'enum strict construit depuis
     MealTypes::MEAL_TYPES (ne recopie pas les valeurs en dur — le vocabulaire
     vit dans le concern) ;
   - "price" : enum "economique" / "moyen" / "cher" ou null ;
   - "tags" : tableau de chaînes dont l'enum est construit dynamiquement depuis
     les noms des tags en base (Tag.alphabetical.pluck(:name)) — l'IA ne peut
     ainsi suggérer QUE des tags existants, aucun mapping flou à faire.
2. Enrichis les prompts (URL-texte, photo, et l'appel du chemin schema.org) avec
   des règles de classification claires, distinctes des règles d'extraction :
   - l'extraction (temps, quantités, étapes) n'invente jamais ; la
     classification (moments, budget, difficulté, régime, tags) est un jugement
     à porter même sans mention explicite dans la source ;
   - diet : le régime le PLUS restrictif réellement applicable (une recette
     sans viande ni poisson est "vegetarien", pas "omnivore" — la hiérarchie
     DIET_COMPATIBILITY du modèle en dépend pour la génération de menus) ;
   - meal_types : tous les moments plausibles (un plat salé classique :
     déjeuner ET dîner) ; petit-déjeuner, goûter et apéro seulement quand c'est
     manifeste ;
   - price : d'après le coût typique des ingrédients ;
   - tags : 0 à 4, uniquement pertinents — liste des tags autorisés injectée
     dans le prompt avec leur type pour guider (cuisine du monde, saison…).
3. Chemin schema.org : il n'appelle Claude que pour structurer les ingrédients.
   Étends CE MÊME appel (pas un appel supplémentaire) pour qu'il classifie
   aussi : envoie-lui nom, description, recipeCategory et instructions en plus
   des ingrédients, et récupère { ingredients, meal_types, price, difficulty,
   diet, tags }. Supprime alors "suggested_tags" et le diet "omnivore" codé en
   dur dans extract_from_schema — devenus du code mort.
4. Dans build_draft_recipe : mappe meal_types (intersection avec
   MealTypes::MEAL_TYPES en garde-fou), price (via valid_enum) et les tags
   (Tag insensible à la casse sur les noms retournés → recipe.tags=). Aucune
   création de tag : un nom inconnu est ignoré silencieusement.
5. Vérifie qu'aucun changement de vue n'est nécessaire (le formulaire lit le
   modèle) et que la liste des brouillons reflète l'amélioration : un import
   avec moments suggérés n'affiche plus « Moment du repas » dans les champs à
   compléter, et passe « Prêt à valider » plus souvent.
6. Ajoute aux specs de requêtes un exemple : avec le service mocké retournant
   meal_types/price/tags, le brouillon créé porte bien les moments, le budget
   et les tags existants (et ignore un nom de tag inconnu).
```

### RSpec

À relancer :

```bash
cd /mnt/c/Caroline/easymeal && bundle exec rspec spec/services spec/requests/recipe_imports_spec.rb spec/requests/recipe_drafts_spec.rb && bundle exec rspec
```

### Vérification de ton côté

- Importe une quiche depuis Marmiton : dans le formulaire de validation, les
  moments « Déjeuner » et « Dîner » doivent être pré-cochés, un budget
  sélectionné, un régime cohérent (végétarien si sans lardons !), et quelques
  tags pertinents cochés dans la section TAGS.
- Importe une recette de gâteau : « Goûter » (et/ou dessert selon tes tags)
  doit ressortir.
- Vérifie que tu peux toujours tout décocher/modifier avant de publier — les
  suggestions ne verrouillent rien.
- Sur /recipe_drafts, la carte d'un nouvel import doit plus souvent afficher
  « Prêt à valider » (le moment du repas n'est plus un manque systématique).
- Publie une recette importée et vérifie-la dans le catalogue : filtres par
  moment, budget et tags doivent la trouver.

### Ce que ça fait

L'IA ne se contente plus d'extraire ce qui est écrit : elle porte un jugement de
classement — à quels repas ce plat correspond, ce qu'il coûte, quels tags de TON
catalogue s'appliquent — et le formulaire de validation arrive pré-coché. La
liste fermée des tags est injectée dans le schéma de sortie : l'IA ne peut
littéralement pas répondre un tag qui n'existe pas. Tu gardes le dernier mot sur
tout, mais valider une recette devient une relecture au lieu d'une saisie.

### Commit proposé

`suggestions IA des moments, budget et tags pré-cochés à la validation`

---

# Étape 8 — Garder la source sous les yeux pendant la validation

> Pour vérifier ce que l'IA a extrait, il faut la source : la page d'origine
> (un clic depuis l'étape 1) mais surtout la photo importée — qui aujourd'hui
> est jetée après extraction.

- **Modèle conseillé** : Opus — effort moyen (migration légère, ActiveStorage/Cloudinary, affichage formulaire)

### Prompt à envoyer

```
**Qualité non négociable** : code simple, refactorisé, DRY, bien commenté, fiable, robuste, zéro code mort, bonnes pratiques Rails/Hotwire/HAML et conventions du projet.

Contexte : pendant la validation d'un brouillon importé, il faut pouvoir
confronter le formulaire à la source. Pour un import URL, source_url est en
base. Pour un import photo, en revanche, le fichier ne sert qu'à l'extraction
puis disparaît : impossible de vérifier une quantité douteuse ou de ressaisir
ce que l'IA a raté. La photo importée n'est PAS forcément une belle photo du
plat : elle ne doit pas devenir recipe.photo, mais être conservée comme pièce
de référence du brouillon.

Fichiers de contexte :
- app/controllers/recipe_imports_controller.rb (build_draft_recipe)
- app/models/recipe.rb (has_one_attached :photo existant)
- app/views/recipes/_form.html.haml et edit.html.haml
- app/views/recipe_drafts/index.html.haml (vignette draft-card__thumb, qui
  n'affiche aujourd'hui que recipe.photo)
- app/helpers/recipes_helper.rb (cloudinary_photo_url)

Demandes :
1. Ajoute has_one_attached :source_photo à Recipe et attache le fichier importé
   dans build_draft_recipe (import photo uniquement). Aucune migration de
   colonne n'est nécessaire avec ActiveStorage — confirme-le.
2. Dans le formulaire d'édition d'un brouillon (uniquement draft?), affiche un
   bandeau « Source de l'import » en tête de formulaire :
   - import URL → lien vers source_url (nouvel onglet) ;
   - import photo → vignette cliquable de source_photo (via cloudinary_photo_url)
     qui ouvre l'image en grand dans un nouvel onglet.
   Sobre et dans la charte (rf-section), pensé comme un pense-bête, pas comme
   un bloc qui pousse le formulaire.
3. Sur la liste des brouillons, la vignette de carte affiche recipe.photo si
   présente, SINON source_photo, sinon le placeholder actuel — un import photo
   devient reconnaissable d'un coup d'œil.
4. Cycle de vie : la pièce est supprimée avec le brouillon (comportement
   ActiveStorage par défaut). À la publication, garde-la (c'est une trace de
   provenance) mais ne l'affiche nulle part ailleurs que dans le formulaire de
   brouillon. Si tu vois une raison forte de la purger à la publication,
   propose-le-moi au lieu de le faire.
5. Ajoute un exemple de spec : un import photo attache source_photo au
   brouillon ; un import URL n'en attache pas.
```

### RSpec

À relancer :

```bash
cd /mnt/c/Caroline/easymeal && bundle exec rspec spec/requests/recipe_imports_spec.rb spec/requests/recipe_drafts_spec.rb && bundle exec rspec
```

### Vérification de ton côté

- Importe une photo de recette : dans le formulaire de validation, la vignette
  de la photo d'origine s'affiche en tête ; clique dessus → l'image s'ouvre en
  grand, tu peux vérifier une quantité en side-by-side.
- La carte du brouillon sur /recipe_drafts montre la photo importée en vignette.
- Importe une URL : le bandeau montre le lien vers la page d'origine.
- Publie la recette : la fiche publique ne montre nulle part la photo de
  magazine (seul recipe.photo compte pour le catalogue).
- Supprime un brouillon photo : pas d'erreur (la pièce jointe part avec).

### Ce que ça fait

La photo importée devient une pièce jointe de référence du brouillon, stockée
comme les autres images (Cloudinary) mais distincte de la photo de présentation.
Pendant la validation, la source est à un clic — fini de retourner chercher le
magazine pour vérifier « 20 cl ou 25 cl ? ».

### Commit proposé

`photo source conservée et affichée pendant la validation d'un import`

---

## Récapitulatif

| #   | Étape                                        | Effort | Risque                        |
| --- | -------------------------------------------- | ------ | ----------------------------- |
| 1   | Badge lien + cartes élargies                 | 30 min | nul                           |
| 2   | Glisser-déposer + collage                    | 1 h    | faible (JS uniquement)        |
| 3   | Redimensionnement photo client               | 1 h    | faible (fallback fichier brut)|
| 4   | Attente progressive + URL conservée          | 45 min | nul                           |
| 5   | Robustesse fetch (redirects, taille, type)   | 45 min | faible                        |
| 6   | Gem anthropic + Sonnet 5 + sorties structurées | 1 h 30 | moyen (cœur de l'import)    |
| 7   | Suggestions moments / budget / tags          | 1 h 30 | moyen (prompts + mapping)     |
| 8   | Photo source conservée à la validation       | 1 h    | faible                        |

Les étapes 1 à 5 sont indépendantes : tu peux t'arrêter, reprendre, ou en sauter
une. Les étapes 6 et 7 forment un bloc ordonné — et gagnent à venir APRÈS les
étapes 10-12 de PROMPTS_REFACTORING.md (filet de tests + service découpé).

### Pistes écartées (et pourquoi)

- **Import asynchrone (job + Turbo Stream)** : la solution « pro » contre les
  longues attentes, mais elle exige une infrastructure de jobs persistants
  (Solid Queue…) et une refonte du parcours. Les étapes 3 et 6 réduisent déjà
  fortement la durée réelle d'extraction. À revisiter seulement si, après elles,
  des imports dépassent encore ~20 s ou si l'appli est déployée derrière un
  proxy qui coupe à 30 s.
- **`capture` sur l'input photo mobile** : forcerait l'appareil photo et
  empêcherait de choisir une image de la galerie — le sélecteur natif propose
  déjà les deux.
- **Création automatique des préparations depuis les ingrédients IA** : le
  panneau « Ingrédients détectés par l'IA » avec ses correspondances
  exact/approché/créer est un bon garde-fou humain ; l'automatiser ferait
  entrer des faux positifs silencieux dans les recettes.

### Pour plus tard

- **Import multi-photos** (recette de magazine sur double page) : l'API accepte
  plusieurs images dans un même message — le formulaire et le contrôleur
  devraient accepter 2-3 fichiers. À chiffrer après l'étape 6.
- **`suitableForDiet` de schema.org** : certains sites déclarent le régime en
  métadonnées ; il pourrait court-circuiter la classification IA du régime
  quand il est présent.
