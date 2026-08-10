# EasyMeal — Instructions pour Claude Code

## Exigences globales de qualité du code

Ces exigences s'appliquent a tout le code du projet, sans exception :

- Produire un code propre, fiable, robuste et maintenable.
- Commenter le code clairement et simplement lorsque cela aide a comprendre l'intention, les choix techniques ou les cas particuliers.
- Respecter le principe DRY : extraire et mutualiser la logique commune au lieu de dupliquer du code.
- Supprimer tout code mort : aucune methode, classe, variable, vue, route, partial, constante ou dependance inutilisee ne doit rester dans le projet.
- Respecter systematiquement les meilleures pratiques du langage, du framework et de l'architecture existante du projet.

## Tester avant de déclarer "terminé"

Avant de dire qu'une tâche est terminée, vérifier systématiquement :

1. **Lire les logs serveur** si disponibles pour détecter les erreurs 500
2. **Tracer le flux de données** : si un champ vient de la DB, vérifier son type réel dans `db/schema.rb` avant de lui appeler des méthodes Ruby (ex: `.parameterize` ne fonctionne que sur String, pas Integer)
3. **Vérifier les enums** : un champ `integer` en base n'a pas forcément un `enum` déclaré dans le modèle — chercher dans le modèle correspondant (`grep enum app/models/`)
4. **Vérifier les méthodes appelées en vue** : chaque méthode appelée sur une variable locale dans un partial doit correspondre au type réel de cette variable

## Architecture du projet

- **Framework** : Ruby on Rails avec Hotwire (Turbo + Stimulus)
- **Vues** : HAML
- **CSS** : Vanilla CSS avec variables custom (`var(--color-*)`)
- **Stimulus** : controllers dans `app/javascript/controllers/` — enregistrés automatiquement via `eagerLoadControllersFrom`
- **Turbo Streams** : templates dans `app/views/<resource>/update.turbo_stream.haml`, etc.

## Conventions importantes

- Les enums Rails exposent la **clé string** via le getter (ex: `item.category` → `"fruits_legumes"`)
- Les traductions des enums `Ingredient` sont dans `Ingredient.human_attribute_name("category.<key>")`
- Les turbo stream responses ignorent le contexte `turbo-frame` — elles s'exécutent toujours
- Stimulus : `eagerLoadControllersFrom` enregistre automatiquement les controllers — nommage `foo_bar_controller.js` → identifier `foo-bar`

## Les moments du repas (UC7)

Le vocabulaire des moments (`breakfast`, `lunch`, `snack`, `apero`, `dinner`) est
porté par le concern `MealTypes` et **par lui seul** :

- `MealTypes::MEAL_TYPES` est la liste ordonnée **comme la journée se déroule** —
  c'est cet ordre qui pilote tous les affichages (chips, steppers, sections). Ne
  jamais réordonner ni redériver cette liste ailleurs.
- Les libellés passent **toujours** par `MealTypes.label` (singulier),
  `.plural_label` (titres de section, steppers), `.short_label(type, count)`
  (barre de résumé) et `.inline_label(type, count)` (au fil d'une phrase). Aucun
  libellé de moment n'est écrit en dur dans une vue, un helper ou un contrôleur
  Stimulus — le français vit dans `config/locales/fr.yml`.
- Deux cardinalités, deux colonnes : `Recipe#meal_types` est un **array**
  PostgreSQL (une quiche vit au déjeuner ET au dîner, scope `for_meal_type`
  via l'index GIN), `MenuRecipe#meal_type` est une **valeur unique** (un repas
  planifié occupe un moment). Ajouter un moment ne coûte jamais de migration.

Les quotas passent par l'objet-valeur **`MealCounts`**, jamais par un hash nu :
il normalise ce qui entre (params, jsonb, menu composé), borne chaque quota et
retire les zéros. Il est stocké en jsonb à deux endroits — `User#default_meal_counts`
(semaine type) et `Menu#requested_meal_counts` (commande d'un menu) — toujours lus
via `User#preferred_meal_counts` / `Menu#requested_counts`.

Deux règles de génération à ne pas casser :

- **La répétition est permise** : une même recette peut apparaître plusieurs fois
  dans un menu (le petit-déj de toute la semaine). L'anti-doublon ne joue qu'à
  l'intérieur d'un même moment.
- **Un pool trop maigre n'est jamais une erreur** à la génération : on place ce
  qu'on peut et `Menu#missing_meal_counts` expose le manque, affiché en tête de
  section. Seul un *remplacement* 🔀 sans candidat lève `Menus::NoCandidatesError`.
