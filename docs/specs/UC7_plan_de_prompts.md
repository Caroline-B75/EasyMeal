# UC7 — Plan de prompts 🗺️

> **Feuille de route d'implémentation** du cahier des charges [UC7_types_de_repas.md](UC7_types_de_repas.md).
> Chaque prompt est **autonome, livrable et testable** : on l'envoie, on vérifie, on committe, on passe au suivant.

---

## 🎯 Les objectifs (rappel)

Transformer EasyMeal pour qu'il pense en **moments de repas** (🥐 petit-déj / 🍽️ déjeuner / 🍪 goûter / 🥂 apéro / 🍲 dîner) :

1. Chaque recette annonce son ou ses moments (`meal_types` multi, obligatoire).
2. On passe commande de sa semaine (5 steppers, mémorisables, option « même petit-déj toute la semaine »).
3. La génération remplit les quotas (répétition permise, remplissage partiel avec message clair).
4. Le brouillon se range par sections, l'ajout se fait **uniquement via le catalogue** pré-filtré.
5. Les cartes s'enrichissent : temps ⏱️, type 🏷️, jour 📅 (optionnel, sans aucun tri), réordonnancement mobile 📱.

**Le document de référence est le cahier des charges — en cas de doute, c'est lui qui a raison.**

---

## 📜 Les règles d'or (à respecter dans TOUS les prompts)

Chaque prompt ci-dessous embarque **déjà** le préambule complet (contexte, règles de
qualité, environnement) : **un seul copier-coller par prompt, rien d'autre à ajouter.**
Les règles, en résumé :

- **Le cahier des charges fait foi** : le suivre à la lettre, signaler tout problème avant de coder.
- **Qualité non négociable** : code simple, refactorisé, DRY, bien commenté, fiable, robuste, zéro code mort, bonnes pratiques Rails/Hotwire/HAML et conventions du projet.
- **Environnement** : Ruby/Rails/rspec via WSL uniquement ; les ~25 specs quantité sont pré-cassées (pas des régressions) ; Claude ne committe jamais.

**Discipline de livraison** : un prompt = une branche de travail propre. Après chaque prompt : je vérifie dans l'app, je lance les tests, **je committe moi-même**, puis j'envoie le prompt suivant.

## 🔄 Gestion des sessions : un prompt = une session

**Règle : `/clear` entre chaque prompt, jamais au milieu d'un prompt.**

- ✅ **`/clear` après chaque prompt validé et committé.** Chaque prompt est autonome par conception : il embarque le préambule, le cahier des charges et ses fichiers de contexte. La mémoire partagée entre les prompts, ce n'est pas la conversation — c'est **le code committé et le cahier des charges**, qu'une session fraîche relit proprement. Bonus : ce n'est pas qu'une économie de tokens — une longue session finit résumée automatiquement, et un contexte résumé pousse Claude à « se souvenir » approximativement au lieu de relire les fichiers. Contexte frais = code plus fiable.
- ⛔ **Jamais de `/clear` pendant qu'on itère sur un prompt** (un test qui casse, un ajustement, une correction) : là, le fil de la conversation est précieux, c'est le contexte du débogage. On reste dans la session du lancement jusqu'au commit.
- 🧭 En résumé : **lancer le prompt → itérer jusqu'au vert → vérifier → committer → `/clear` → prompt suivant.**

---

## Prompt 0 — 🔍 État des lieux du catalogue (le prérequis)

> Le cahier des charges est formel : la fonctionnalité ne vaudra que ce que valent les pools. On mesure avant de construire.

**⚠️ À bien comprendre : ce prompt n'a PAS besoin de `meal_types` (qui n'existe pas encore).** Claude lit simplement les _noms_ des recettes existantes et fait un classement **estimatif, à l'œil** (« Pancakes → petit-déj/goûter, Houmous → apéro… »), comme tu le ferais toi-même avec la liste sous les yeux. Objectif double :

1. **Savoir avant de construire** si des pools seront vides (ex : 0 recette d'apéro) → importer des recettes en parallèle du chantier, plutôt que de le découvrir sur la démo du Prompt 5.
2. **Préparer la checklist de re-tagage** : le Prompt 1 backfille toutes les recettes en « Déjeuner + Dîner » ; après le Prompt 2, il faudra corriger à la main les vrais petits-déjs/goûters/apéros — le tableau du Prompt 0 est exactement cette liste de correction.

_(Si ton catalogue est petit et que tu le connais par cœur, ce prompt est sautable — c'est de la mesure, pas de la construction.)_

- **Modèle conseillé** : Sonnet — effort faible (lecture seule, aucune modification de code)
- **Contexte** : savoir combien de recettes pourront être taguées petit-déj, goûter, apéro, pour anticiper les pools vides.
- **Fichiers de contexte** : `db/schema.rb`, `app/models/recipe.rb`

```text
Contexte : nous implémentons le cahier des charges docs/specs/UC7_types_de_repas.md.
Suis-le à la lettre, sans changer aucune décision ni aucun arbitrage. Si tu vois un
problème ou une incohérence, SIGNALE-le-moi et attends ma réponse avant de coder.

Règles de qualité NON NÉGOCIABLES :
- Code simple, refactorisé, DRY : mutualiser au lieu de dupliquer.
- Bien commenté (intention, choix techniques, cas particuliers), fiable et robuste.
- AUCUN code mort : supprimer toute méthode, route, vue, scope, colonne ou dépendance
  devenue inutile.
- Respecter les bonnes pratiques Rails / Hotwire / HAML et les conventions du projet
  (CLAUDE.md) : vanilla CSS avec var(--color-*), boutons via les classes canoniques
  de components.css, controllers Stimulus auto-enregistrés.
Environnement :
- Ruby/Rails/rspec s'exécutent UNIQUEMENT via WSL (jamais en PowerShell direct).
- Les ~25 specs quantité (humanize/scale) sont cassées d'avance : ce ne sont PAS des
  régressions. Toute AUTRE spec qui casse en est une.
- Ne committe jamais : je committe moi-même après vérification.

--- LA MISSION DE CE PROMPT ---

Sans rien modifier au code : via WSL et rails runner, dresse un état des lieux du
catalogue de recettes publiées. Liste les noms de toutes les recettes et propose-moi
un classement estimatif par moment de repas (petit-déj / déjeuner / goûter / apéro /
dîner — plusieurs moments possibles par recette). Donne-moi un tableau récapitulatif
des effectifs estimés par moment, et signale les pools qui seraient trop maigres
pour une semaine type (7 petits-déjs, 2 déjs, 7 goûters, 1 apéro, 7 dîners).

Termine par une explication simple et ludique (3-5 phrases) : ce que tu as trouvé,
et ce que je devrais faire avant de continuer (ex : importer des recettes de
petit-déj via l'import IA).
```

- **Tests** : aucun (lecture seule).
- **✅ Je vérifie** : le tableau me semble crédible par rapport à mon catalogue.

---

## Prompt 1 — 🧱 Fondations : migrations et modèles

> Tout le chantier repose sur ces colonnes. On les pose d'abord, sans toucher à l'interface.

- **Modèle conseillé** : Opus — effort élevé (migrations avec backfill, suppression de contrainte : zéro droit à l'erreur)
- **Contexte** : chapitres 1 et 3 du cahier des charges, partie données uniquement.
- **Fichiers de contexte** : `db/schema.rb`, `app/models/recipe.rb`, `app/models/menu_recipe.rb`, `app/models/menu.rb`, `app/services/groceries/build_for_menu_service.rb`

```text
Contexte : nous implémentons le cahier des charges docs/specs/UC7_types_de_repas.md.
Suis-le à la lettre, sans changer aucune décision ni aucun arbitrage. Si tu vois un
problème ou une incohérence, SIGNALE-le-moi et attends ma réponse avant de coder.

Règles de qualité NON NÉGOCIABLES :
- Code simple, refactorisé, DRY : mutualiser au lieu de dupliquer.
- Bien commenté (intention, choix techniques, cas particuliers), fiable et robuste.
- AUCUN code mort : supprimer toute méthode, route, vue, scope, colonne ou dépendance
  devenue inutile.
- Respecter les bonnes pratiques Rails / Hotwire / HAML et les conventions du projet
  (CLAUDE.md) : vanilla CSS avec var(--color-*), boutons via les classes canoniques
  de components.css, controllers Stimulus auto-enregistrés.

Environnement :
- Ruby/Rails/rspec s'exécutent UNIQUEMENT via WSL (jamais en PowerShell direct).
- Les ~25 specs quantité (humanize/scale) sont cassées d'avance : ce ne sont PAS des
  régressions. Toute AUTRE spec qui casse en est une.
- Ne committe jamais : je committe moi-même après vérification.

--- LA MISSION DE CE PROMPT ---

Implémente UNIQUEMENT la couche données du cahier des charges (aucun changement
d'interface dans ce prompt) :

1. Migration : ajoute recipes.meal_types (string array PostgreSQL, default [],
   null: false) — même idiome que ingredients.season_months. Backfill de toutes
   les recettes existantes à ["lunch", "dinner"].
2. Migration : ajoute menu_recipes.day_of_week (integer, nullable, sans default).
3. Migration : supprime menu_recipes.scheduled_date (code mort jamais branché)
   ainsi que son index, et nettoie les scopes/méthodes du modèle qui y font
   référence.
4. Migration : supprime l'index unique menu_id+recipe_id de menu_recipes (une
   recette peut désormais apparaître plusieurs fois dans un menu) et retire la
   validation d'unicité correspondante du modèle. Vérifie que la génération de la
   liste de courses (Groceries::BuildForMenuService) reste correcte avec des
   recettes en double : les quantités des doublons doivent s'additionner.
5. Modèle MenuRecipe : ajoute "apero" à MEAL_TYPES (ordre : breakfast, lunch,
   snack, apero, dinner).
6. Modèle Recipe : validation « au moins un meal_type » SAUF pour les brouillons
   (même exemption que la règle "au moins un ingrédient") ; ajoute "Moment du
   repas" à draft_missing_fields ; ajoute un scope for_meal_type(type) (l'array
   contient le type) ; ajoute les traductions françaises des 5 moments.
7. Toutes les migrations doivent être réversibles.

Écris les specs modèles correspondantes (validation meal_types, exemption
brouillon, scope for_meal_type, doublons autorisés, courses avec doublons).
Lance toute la suite rspec via WSL et donne-moi le bilan.

Termine par une explication simple et ludique (3-5 phrases) de ce qui a été fait
et de ce que je peux vérifier moi-même (ex : en console rails, quelle commande
taper pour voir les meal_types d'une recette).
```

- **Tests** : suite rspec complète (hors 25 specs quantité pré-cassées) + nouvelles specs modèles. `rails db:migrate` puis `rails db:rollback STEP=4` doivent passer.
- **✅ Je vérifie** : l'app démarre, mes recettes existantes affichent toujours tout normalement.

---

## Prompt 2 — 🏷️ La fiche recette annonce ses moments

- **Modèle conseillé** : Sonnet — effort moyen (formulaire + affichage, périmètre bien borné)
- **Contexte** : chapitre 1 du cahier des charges, partie interface.
- **Fichiers de contexte** : `app/views/recipes/` (form, show, edit, new), `app/models/recipe.rb`, `app/controllers/recipes_controller.rb`, `app/assets/stylesheets/components.css`, la charte graphique `.github/charte-graphique.md`

```text
Contexte : nous implémentons le cahier des charges docs/specs/UC7_types_de_repas.md.
Suis-le à la lettre, sans changer aucune décision ni aucun arbitrage. Si tu vois un
problème ou une incohérence, SIGNALE-le-moi et attends ma réponse avant de coder.

Règles de qualité NON NÉGOCIABLES :
- Code simple, refactorisé, DRY : mutualiser au lieu de dupliquer.
- Bien commenté (intention, choix techniques, cas particuliers), fiable et robuste.
- AUCUN code mort : supprimer toute méthode, route, vue, scope, colonne ou dépendance
  devenue inutile.
- Respecter les bonnes pratiques Rails / Hotwire / HAML et les conventions du projet
  (CLAUDE.md) : vanilla CSS avec var(--color-*), boutons via les classes canoniques
  de components.css, controllers Stimulus auto-enregistrés.

Environnement :
- Ruby/Rails/rspec s'exécutent UNIQUEMENT via WSL (jamais en PowerShell direct).
- Les ~25 specs quantité (humanize/scale) sont cassées d'avance : ce ne sont PAS des
  régressions. Toute AUTRE spec qui casse en est une.
- Ne committe jamais : je committe moi-même après vérification.

--- LA MISSION DE CE PROMPT ---

Dans le formulaire de création/édition de recette, ajoute le champ obligatoire
« Moment(s) du repas » : une rangée de 5 chips à cocher (cases à cocher stylées) —
Petit-déj / Déjeuner / Goûter / Apéro / Dîner — multi-sélection, au moins une
obligatoire (message d'erreur clair en français). Affiche aussi les moments sur la
page de détail d'une recette (badges discrets, cohérents avec la charte graphique).

Pour les brouillons importés par IA : le champ est présent dans le formulaire de
complétion mais l'enregistrement du brouillon reste possible sans lui (la
validation ne s'applique qu'à la publication), et « Moment du repas » apparaît
dans la liste des champs manquants du brouillon.

Écris/adapte les specs (création avec et sans moments, brouillon IA exempté).
Lance la suite rspec via WSL et donne-moi le bilan.

Termine par une explication simple et ludique (3-5 phrases) : ce qui a été fait,
et où cliquer pour vérifier (créer une recette sans cocher de moment → erreur ;
un brouillon IA → pas d'erreur).
```

- **Tests** : specs requests/system recettes ; régression : création/édition de recette classique, flux d'import IA.
- **✅ Je vérifie** : je crée une recette en cochant « Déjeuner + Dîner », les badges apparaissent sur sa fiche ; sans rien cocher, message d'erreur.

---

## Prompt 3 — 🔎 Le catalogue filtre par moment

> Petit prompt volontairement isolé : ce filtre servira de fondation aux boutons « + catalogue » du Prompt 6.

- **Modèle conseillé** : Sonnet — effort moyen
- **Contexte** : chapitre 5 du cahier des charges.
- **Fichiers de contexte** : `app/services/recipes/filter_service.rb`, `app/controllers/recipes_controller.rb`, les vues du catalogue (`app/views/recipes/index*`), le partial des filtres existants

```text
Contexte : nous implémentons le cahier des charges docs/specs/UC7_types_de_repas.md.
Suis-le à la lettre, sans changer aucune décision ni aucun arbitrage. Si tu vois un
problème ou une incohérence, SIGNALE-le-moi et attends ma réponse avant de coder.

Règles de qualité NON NÉGOCIABLES :
- Code simple, refactorisé, DRY : mutualiser au lieu de dupliquer.
- Bien commenté (intention, choix techniques, cas particuliers), fiable et robuste.
- AUCUN code mort : supprimer toute méthode, route, vue, scope, colonne ou dépendance
  devenue inutile.
- Respecter les bonnes pratiques Rails / Hotwire / HAML et les conventions du projet
  (CLAUDE.md) : vanilla CSS avec var(--color-*), boutons via les classes canoniques
  de components.css, controllers Stimulus auto-enregistrés.

Environnement :
- Ruby/Rails/rspec s'exécutent UNIQUEMENT via WSL (jamais en PowerShell direct).
- Les ~25 specs quantité (humanize/scale) sont cassées d'avance : ce ne sont PAS des
  régressions. Toute AUTRE spec qui casse en est une.
- Ne committe jamais : je committe moi-même après vérification.

--- LA MISSION DE CE PROMPT ---

Ajoute un filtre « Moment du repas » au catalogue de recettes : un scope de plus
dans Recipes::FilterService (s'appuyant sur Recipe.for_meal_type du Prompt 1) et
son contrôle dans l'interface de filtres, cohérent avec les filtres existants
(régime, difficulté, temps). Le filtre doit être pilotable par paramètre d'URL
(ex : ?meal_type=breakfast) car il sera pré-appliqué par des liens entrants dans
une étape ultérieure.

Écris les specs du FilterService pour ce filtre (seul et combiné avec le régime).
Lance la suite rspec via WSL et donne-moi le bilan.

Termine par une explication simple et ludique (3-5 phrases) : ce qui a été fait
et comment vérifier (filtrer le catalogue sur « Petit-déj », vérifier l'URL).
```

- **Tests** : specs FilterService ; régression : les autres filtres et la recherche fonctionnent toujours, seuls et combinés.
- **✅ Je vérifie** : je filtre le catalogue par « Goûter » et je ne vois que les bonnes recettes ; je combine avec un régime.

---

## Prompt 4 — 🎛️ On passe commande de sa semaine (formulaire de génération)

- **Modèle conseillé** : Opus — effort élevé (formulaire + Stimulus + préférences utilisateur, beaucoup d'interactions)
- **Contexte** : chapitre 2 du cahier des charges.
- **Fichiers de contexte** : `app/views/menus/_params_form.html.haml`, `app/javascript/controllers/menu_generate_controller.js`, `app/models/user.rb`, `app/controllers/menus_controller.rb`, `db/schema.rb`

```text
Contexte : nous implémentons le cahier des charges docs/specs/UC7_types_de_repas.md.
Suis-le à la lettre, sans changer aucune décision ni aucun arbitrage. Si tu vois un
problème ou une incohérence, SIGNALE-le-moi et attends ma réponse avant de coder.

Règles de qualité NON NÉGOCIABLES :
- Code simple, refactorisé, DRY : mutualiser au lieu de dupliquer.
- Bien commenté (intention, choix techniques, cas particuliers), fiable et robuste.
- AUCUN code mort : supprimer toute méthode, route, vue, scope, colonne ou dépendance
  devenue inutile.
- Respecter les bonnes pratiques Rails / Hotwire / HAML et les conventions du projet
  (CLAUDE.md) : vanilla CSS avec var(--color-*), boutons via les classes canoniques
  de components.css, controllers Stimulus auto-enregistrés.

Environnement :
- Ruby/Rails/rspec s'exécutent UNIQUEMENT via WSL (jamais en PowerShell direct).
- Les ~25 specs quantité (humanize/scale) sont cassées d'avance : ce ne sont PAS des
  régressions. Toute AUTRE spec qui casse en est une.
- Ne committe jamais : je committe moi-même après vérification.

--- LA MISSION DE CE PROMPT ---

Transforme le formulaire de génération de menu (carte 3 « Nombre de repas ») :

1. Remplace le slider unique par 5 steppers − / + (un par moment : Petit-déj,
   Déjeuner, Goûter, Apéro, Dîner), bornés 0–14. Valeurs par défaut au premier
   passage : 0 partout SAUF Déjeuners et Dîners (pré-remplis depuis l'ancien
   comportement). Au moins 1 repas au total pour pouvoir générer.
2. Ajoute une case à cocher « Mon petit-déjeuner est le même toute la semaine »,
   visible/active uniquement si le stepper Petit-déj est ≥ 2.
3. La barre de résumé en temps réel affiche la répartition (ex : « 7 petits-déjs
   · 2 déjs · 7 goûters · 1 apéro · 7 dîners ») — n'affiche que les moments > 0.
4. Migration : remplace User.default_number_of_meals par une colonne
   default_meal_counts (jsonb, default {}) qui mémorise la répartition complète
   (+ l'option petit-déj identique). La case « Mémoriser ces paramètres »
   enregistre désormais cette répartition ; le formulaire la pré-remplit ensuite.
   Supprime proprement default_number_of_meals partout (code mort).
5. Le contrôleur transmet la répartition au service de génération SANS changer
   le service dans ce prompt : adapte l'appel au minimum (ex : total des quotas)
   pour que la génération actuelle continue de fonctionner — le moteur par quotas
   arrive au prompt suivant.

Écris/adapte les specs (préférences mémorisées, pré-remplissage, validation
« au moins 1 repas »). Lance la suite rspec via WSL et donne-moi le bilan.

Termine par une explication simple et ludique (3-5 phrases) : ce qui a été fait
et comment vérifier (générer un menu, cocher « Mémoriser », revenir sur le
formulaire → ma répartition est pré-remplie).
```

- **Tests** : specs User (préférences), specs requests génération ; régression : la génération de menu fonctionne toujours de bout en bout, le stepper de personnes et le régime sont intacts.
- **✅ Je vérifie** : je règle 7/2/7/1/7, je coche « Mémoriser », je génère ; je reviens → tout est pré-rempli.

---

## Prompt 5 — ⚙️ Le moteur honore la commande (génération par quotas)

- **Modèle conseillé** : **Fable — effort élevé** (cœur algorithmique du chantier : quotas, saison, répétition, remplissage partiel)
- **Contexte** : chapitre 3 du cahier des charges.
- **Fichiers de contexte** : `app/services/menus/generate_service.rb`, `app/services/menus/candidate_picker_service.rb`, `app/services/menus/regenerate_service.rb`, `app/services/menus/replace_meal_service.rb`, `app/models/menu.rb`, `app/controllers/menus_controller.rb`

```text
Contexte : nous implémentons le cahier des charges docs/specs/UC7_types_de_repas.md.
Suis-le à la lettre, sans changer aucune décision ni aucun arbitrage. Si tu vois un
problème ou une incohérence, SIGNALE-le-moi et attends ma réponse avant de coder.

Règles de qualité NON NÉGOCIABLES :
- Code simple, refactorisé, DRY : mutualiser au lieu de dupliquer.
- Bien commenté (intention, choix techniques, cas particuliers), fiable et robuste.
- AUCUN code mort : supprimer toute méthode, route, vue, scope, colonne ou dépendance
  devenue inutile.
- Respecter les bonnes pratiques Rails / Hotwire / HAML et les conventions du projet
  (CLAUDE.md) : vanilla CSS avec var(--color-*), boutons via les classes canoniques
  de components.css, controllers Stimulus auto-enregistrés.

Environnement :
- Ruby/Rails/rspec s'exécutent UNIQUEMENT via WSL (jamais en PowerShell direct).
- Les ~25 specs quantité (humanize/scale) sont cassées d'avance : ce ne sont PAS des
  régressions. Toute AUTRE spec qui casse en est une.
- Ne committe jamais : je committe moi-même après vérification.

--- LA MISSION DE CE PROMPT ---

Fais passer le moteur de génération aux quotas par moment :

1. Migration : ajoute menus.requested_meal_counts (jsonb, default {}) — la
   commande passée à la génération y est mémorisée, pour afficher les manques
   dans le brouillon et re-générer à l'identique.
2. Menus::GenerateService reçoit la répartition {type => quantité} : pour chaque
   moment, il pioche dans le pool des recettes publiées, compatibles régime ET
   taguées de ce moment, avec la priorité saison conservée À L'INTÉRIEUR de
   chaque quota. Chaque MenuRecipe créé porte son meal_type.
3. Option « même petit-déjeuner toute la semaine » : une seule recette piochée,
   placée N fois (N cartes distinctes).
4. Pool insuffisant : on remplit ce qu'on peut, JAMAIS d'erreur. Le Menu expose
   les manques par moment (méthode missing_meal_counts comparant
   requested_meal_counts aux repas présents) — l'affichage arrive au prompt 6.
5. Menus::CandidatePickerService accepte un paramètre meal_type et restreint son
   pool en conséquence. Le remplacement 🔀 d'une carte tire désormais dans le
   pool du même moment.
6. La re-génération (changement de régime depuis le panneau de réglages) réutilise
   requested_meal_counts au lieu du nombre de repas.
7. Comme les doublons sont permis, le tirage n'exclut plus les recettes déjà
   présentes SAUF pour éviter deux fois la même recette dans le MÊME moment
   (hors option petit-déj identique) — et le remplacement exclut la recette
   remplacée.

Écris des specs service complètes : quotas respectés, priorité saison par pool,
petit-déj identique ×N, remplissage partiel + missing_meal_counts, remplacement
dans le bon moment, re-génération. Lance la suite rspec via WSL, bilan.

Termine par une explication simple et ludique (3-5 phrases) : ce qui a été fait
et comment vérifier en console (générer avec 2 petits-déjs demandés alors que le
catalogue n'en a qu'un → missing_meal_counts le signale).
```

- **Tests** : specs services (le cœur du chantier — être exigeant ici) ; régression : génération, remplacement, re-génération de régime, liste de courses.
- **✅ Je vérifie** : je génère avec ma semaine type ; chaque repas a le bon type ; le remplacement d'un dîner redonne un dîner.

---

## Prompt 6 — 🗂️ Le brouillon rangé par sections

- **Modèle conseillé** : **Fable — effort élevé** (refonte de la vue centrale de l'app + suppressions de code + Turbo Streams)
- **Contexte** : chapitre 4 du cahier des charges (structure), chapitre 3 (messages de manque).
- **Fichiers de contexte** : `app/views/menus/_draft_view.html.haml`, `app/views/menus/_menu_recipe_card.html.haml`, `app/views/menus/add_random_meal.turbo_stream.haml`, `app/services/menus/add_random_meal_service.rb`, `app/services/menus/toggle_draft_recipe_service.rb`, `app/javascript/controllers/menu_customize_controller.js`, `config/routes.rb`, `app/assets/stylesheets/menus.css`

```text
Contexte : nous implémentons le cahier des charges docs/specs/UC7_types_de_repas.md.
Suis-le à la lettre, sans changer aucune décision ni aucun arbitrage. Si tu vois un
problème ou une incohérence, SIGNALE-le-moi et attends ma réponse avant de coder.

Règles de qualité NON NÉGOCIABLES :
- Code simple, refactorisé, DRY : mutualiser au lieu de dupliquer.
- Bien commenté (intention, choix techniques, cas particuliers), fiable et robuste.
- AUCUN code mort : supprimer toute méthode, route, vue, scope, colonne ou dépendance
  devenue inutile.
- Respecter les bonnes pratiques Rails / Hotwire / HAML et les conventions du projet
  (CLAUDE.md) : vanilla CSS avec var(--color-*), boutons via les classes canoniques
  de components.css, controllers Stimulus auto-enregistrés.

Environnement :
- Ruby/Rails/rspec s'exécutent UNIQUEMENT via WSL (jamais en PowerShell direct).
- Les ~25 specs quantité (humanize/scale) sont cassées d'avance : ce ne sont PAS des
  régressions. Toute AUTRE spec qui casse en est une.
- Ne committe jamais : je committe moi-même après vérification.

--- LA MISSION DE CE PROMPT ---

Réorganise la vue brouillon du menu en sections par moment :

1. La grille se regroupe en sections dans l'ordre : Petits-déjeuners, Déjeuners,
   Goûters, Apéros, Dîners (une section n'apparaît que si elle contient des repas
   OU qu'il en manque). En tête de section : le nom, le compte (ex « Dîners (5/7) »)
   et, si missing_meal_counts le signale, le message ludique du cahier des
   charges : « Il manque X … — ajoute-les depuis le catalogue ! ».
2. Chaque section porte son unique bouton « + catalogue » : lien vers le
   catalogue pré-filtré sur le moment de la section (filtre du Prompt 3), et
   l'ajout d'une recette depuis ce contexte crée le MenuRecipe avec le bon
   meal_type (adapte Menus::ToggleDraftRecipeService et le flux catalogue →
   menu pour transporter ce paramètre).
3. SUPPRIME ENTIÈREMENT l'ajout aléatoire post-génération : bouton « Repas
   aléatoire », route, action de contrôleur, add_random_meal_service,
   template turbo_stream — aucun code mort ne doit rester. Le bouton 🔀 de
   remplacement sur les cartes est CONSERVÉ.
4. Le drag & drop de réordonnancement existant continue de fonctionner, mais
   uniquement À L'INTÉRIEUR d'une section (on ne change pas de moment en
   glissant — c'est le dropdown du prompt 7 qui fera ça).
5. Les Turbo Streams existants (remplacement, suppression, stepper de personnes)
   restent cohérents avec la nouvelle structure en sections.

Adapte les specs de vues/requests impactées. Lance la suite rspec via WSL, bilan.

Termine par une explication simple et ludique (3-5 phrases) : ce qui a été fait
et comment vérifier (générer ma semaine type → les sections apparaissent ; un
pool insuffisant → le message s'affiche ; le bouton aléatoire a disparu).
```

- **Tests** : specs requests/system du brouillon ; régression : validation du menu, liste de courses, remplacement, suppression de carte, changement de régime.
- **✅ Je vérifie** : mes repas sont rangés par sections ; « + catalogue » depuis la section Goûters m'amène au catalogue filtré Goûters et la recette ajoutée atterrit dans la bonne section.

---

## Prompt 7 — 🃏 Les cartes s'enrichissent

- **Modèle conseillé** : Sonnet — effort élevé (beaucoup de petits éléments UI, mécaniques déjà éprouvées à imiter)
- **Contexte** : chapitre 4 du cahier des charges, bloc « Les cartes de repas s'enrichissent aussi ».
- **Fichiers de contexte** : `app/views/menus/_menu_recipe_card.html.haml`, `app/controllers/menu_recipes_controller.rb`, `app/javascript/controllers/menu_customize_controller.js`, `app/assets/stylesheets/menus.css`, `app/assets/stylesheets/components.css`, `app/models/menu_recipe.rb`

```text
Contexte : nous implémentons le cahier des charges docs/specs/UC7_types_de_repas.md.
Suis-le à la lettre, sans changer aucune décision ni aucun arbitrage. Si tu vois un
problème ou une incohérence, SIGNALE-le-moi et attends ma réponse avant de coder.

Règles de qualité NON NÉGOCIABLES :
- Code simple, refactorisé, DRY : mutualiser au lieu de dupliquer.
- Bien commenté (intention, choix techniques, cas particuliers), fiable et robuste.
- AUCUN code mort : supprimer toute méthode, route, vue, scope, colonne ou dépendance
  devenue inutile.
- Respecter les bonnes pratiques Rails / Hotwire / HAML et les conventions du projet
  (CLAUDE.md) : vanilla CSS avec var(--color-*), boutons via les classes canoniques
  de components.css, controllers Stimulus auto-enregistrés.

Environnement :
- Ruby/Rails/rspec s'exécutent UNIQUEMENT via WSL (jamais en PowerShell direct).
- Les ~25 specs quantité (humanize/scale) sont cassées d'avance : ce ne sont PAS des
  régressions. Toute AUTRE spec qui casse en est une.
- Ne committe jamais : je committe moi-même après vérification.

--- LA MISSION DE CE PROMPT ---

Enrichis la carte de repas du brouillon, en respectant scrupuleusement les
décisions du cahier des charges :

1. ⏱️ Badge temps : affiche Recipe#total_time_minutes (ex « 35 min ») sur la
   carte ; rien si aucun temps renseigné.
2. 🏷️ Dropdown type de repas : sélecteur Petit-déj / Déjeuner / Goûter / Apéro /
   Dîner, même mécanique auto-submit que le sélecteur de personnes. Le changer
   déplace la carte vers sa nouvelle section (réponse Turbo Stream qui re-rend
   les sections concernées).
3. 📅 Dropdown jour : « — / Lundi / … / Dimanche » (day_of_week 0–6, vide par
   défaut), même mécanique auto-submit, et un badge discret sur la carte quand le
   jour est renseigné. AUCUNE logique de tri, de groupement ou de validation :
   la position manuelle reste la seule vérité d'ordre.
4. 📱 Sur mobile uniquement : boutons discrets ⬆️ monter / ⬇️ descendre pour
   réordonner la carte dans sa section (le drag & drop HTML5 ne marche pas au
   tactile). Utilise les classes canoniques de boutons de components.css.
5. Attention à la densité : la carte reste compacte et lisible — regroupe
   intelligemment les contrôles, propose-moi une maquette texte AVANT de coder
   si tu vois un risque de surcharge.

Adapte/écris les specs (changement de type → bonne section, changement de jour,
monter/descendre aux bornes de section). Lance la suite rspec via WSL, bilan.

Termine par une explication simple et ludique (3-5 phrases) : ce qui a été fait
et comment vérifier sur desktop ET sur mobile (mode responsive du navigateur).
```

- **Tests** : specs requests menu_recipes (update type/jour/position) ; régression : sélecteur de personnes, remplacement, suppression, drag & drop desktop.
- **✅ Je vérifie** : je passe une quiche de « Déjeuner » à « Dîner » → elle change de section ; je lui mets « Mardi » → badge ; sur mobile je monte/descends une carte.

---

## Prompt 8 — 🧹 La revue finale du CTO

- **Modèle conseillé** : Opus — effort élevé (ou la commande `/code-review high` sur la branche)
- **Contexte** : tout le chantier UC7 est livré ; on verrouille la qualité.
- **Fichiers de contexte** : l'ensemble du diff de la branche UC7.

```text
Contexte : nous implémentons le cahier des charges docs/specs/UC7_types_de_repas.md.
Suis-le à la lettre, sans changer aucune décision ni aucun arbitrage. Si tu vois un
problème ou une incohérence, SIGNALE-le-moi et attends ma réponse avant de coder.

Règles de qualité NON NÉGOCIABLES :
- Code simple, refactorisé, DRY : mutualiser au lieu de dupliquer.
- Bien commenté (intention, choix techniques, cas particuliers), fiable et robuste.
- AUCUN code mort : supprimer toute méthode, route, vue, scope, colonne ou dépendance
  devenue inutile.
- Respecter les bonnes pratiques Rails / Hotwire / HAML et les conventions du projet
  (CLAUDE.md) : vanilla CSS avec var(--color-*), boutons via les classes canoniques
  de components.css, controllers Stimulus auto-enregistrés.

Environnement :
- Ruby/Rails/rspec s'exécutent UNIQUEMENT via WSL (jamais en PowerShell direct).
- Les ~25 specs quantité (humanize/scale) sont cassées d'avance : ce ne sont PAS des
  régressions. Toute AUTRE spec qui casse en est une.
- Ne committe jamais : je committe moi-même après vérification.

--- LA MISSION DE CE PROMPT ---

Le chantier UC7 est terminé. Fais une revue complète de la branche :

1. Chasse au code mort : plus AUCUNE trace de scheduled_date,
   default_number_of_meals, add_random_meal, ni de l'ancienne contrainte
   d'unicité — vérifie routes, vues, services, specs, traductions, CSS.
2. DRY : repère les logiques dupliquées introduites pendant le chantier
   (libellés des moments, options de dropdowns, ordre des sections…) et
   mutualise-les (helper, constante, partial).
3. Cohérence avec le cahier des charges : relis docs/specs/UC7_types_de_repas.md
   point par point et liste ce qui est fait / pas fait / différent.
4. Lance TOUTE la suite rspec via WSL et donne le bilan exact (en rappelant les
   25 specs quantité pré-cassées).
5. Mets à jour docs/specs/roadmap.md et CLAUDE.md si des conventions nouvelles
   méritent d'y figurer (ex : meal_types array, quotas).

Termine par une explication simple et ludique (5-6 phrases) : l'état final du
chantier, ce qui reste éventuellement à faire, et une petite liste de vérifications
manuelles de bout en bout que je peux dérouler en 10 minutes dans l'app.
```

- **Tests** : la suite complète, une dernière fois.
- **✅ Je vérifie** : je déroule la checklist de bout en bout fournie, puis je merge. 🎉

---

## 🧭 Récapitulatif du séquençage

|  #  | Prompt                      | Modèle / effort   | Dépend de |
| :-: | --------------------------- | ----------------- | :-------: |
|  0  | État des lieux du catalogue | Sonnet / faible   |     —     |
|  1  | Fondations données          | Opus / élevé      |     —     |
|  2  | Fiche recette (chips)       | Sonnet / moyen    |     1     |
|  3  | Filtre catalogue            | Sonnet / moyen    |     1     |
|  4  | Formulaire de génération    | Opus / élevé      |     1     |
|  5  | Moteur par quotas           | **Fable / élevé** |   1, 4    |
|  6  | Brouillon en sections       | **Fable / élevé** |   3, 5    |
|  7  | Cartes enrichies            | Sonnet / élevé    |     6     |
|  8  | Revue finale                | Opus / élevé      |   tout    |

**Trois conseils de CTO pour finir** 😎 :

1. **Ne saute jamais un prompt** et n'en fusionne pas deux : le découpage garantit qu'une régression est toujours facile à localiser.
2. **Committe après chaque prompt validé** (c'est toi qui committes, jamais Claude) : en cas de pépin, on revient d'un seul cran.
3. **Le Prompt 0 n'est pas optionnel** : si le catalogue n'a pas de recettes de petit-déj, commence par en importer quelques-unes — sinon la démo du Prompt 5 sera décevante alors que le code sera juste.
