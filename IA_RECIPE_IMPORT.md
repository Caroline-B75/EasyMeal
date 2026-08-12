# Import IA de Recettes — Plan d'implémentation

## Contexte et objectif

Permettre à l'admin d'importer des recettes depuis deux sources :
- **Une URL** (fiche recette sur un site internet)
- **Une photo** (recette dans un magazine, prise depuis le desktop)

L'IA (Claude Sonnet API) extrait les données structurées. L'admin valide, complète et publie la recette. Aucune recette n'est enregistrée en base sans validation humaine explicite.

---

## Règles métier validées

1. **Admin uniquement** — seul `user.admin?` peut importer, reviewer et publier une recette via l'IA
2. **Pas de photo automatique** — la photo du plat est ajoutée manuellement par l'admin (Cloudinary, desktop) lors de la review
3. **Validation obligatoire** — toute recette importée commence en statut `draft`, invisible des utilisateurs
4. **Brouillon persistant** — l'admin peut sauvegarder un brouillon et y revenir plus tard
5. **Suppression de brouillon** — l'admin peut supprimer un brouillon à tout moment
6. **Alias automatique** — si l'admin valide un match approximatif (ex: "crème fraîche épaisse" → "crème fraîche"), le nom IA est ajouté en alias sur l'ingrédient existant
7. **Échec API** — si Claude API échoue (mauvaise photo, URL inaccessible), message d'erreur flash + retour au formulaire, aucun enregistrement créé
8. **Modèle IA** — Claude Sonnet (meilleur rapport qualité/coût pour de l'extraction structurée)

---

## Décisions architecturales et arbitrages

### Statut des recettes : enum Rails natif (pas AASM)
- **Choix** : `enum :status, { draft: 0, published: 1 }, default: :published`
- **Pourquoi** : 2 états seulement, AASM serait du sur-engineering
- **Défaut** : `published` pour toutes les recettes existantes, `draft` pour les imports IA

### Pas de modèle `RecipeImport` séparé
- **Choix** : le draft **est** une `Recipe` avec `status: :draft`
- **Pourquoi** : évite la duplication de logique, réutilise le formulaire `edit` existant
- **Colonnes ajoutées** : `status`, `source_type` (string: url/photo/manual), `ai_raw_data` (jsonb)

### Autorisation : Pundit (pas de namespace Admin)
- **Choix** : nouvelles policies `RecipeDraftPolicy` et `RecipeImportPolicy`, mise à jour de `RecipePolicy`
- **Pourquoi** : Pundit est déjà en place, cohérence avec l'existant
- **`RecipePolicy::Scope`** : retourne `scope.all` pour admin, `scope.where(status: :published)` pour les autres

### Pas de namespace de routes Admin
- **Choix** : routes `recipe_drafts` et `recipe_imports` au même niveau que les routes existantes
- **Protection** : `authorize` Pundit dans chaque action de controller

### Sidebar de création d'ingrédient : réutilisation de `quick_create`
- **Choix** : le endpoint `POST /ingredients/quick_create` existant est réutilisé tel quel
- **Pourquoi** : déjà fonctionnel et testé depuis `recipes/new`, évite toute duplication

### Matching d'ingrédients : fuzzy via trigram PostgreSQL
- **Index existant** : `gin_trgm_ops` sur `ingredients.name` — déjà en place
- **Seuils retenus** : `similarity > 0.3` sur la chaîne entière (fautes de frappe),
  `word_similarity > 0.6` par mots — c'est elle qui rapproche « thym » de « Thym frais »
- **Nom réduit** : les quantificateurs de tête (« brin de », « gousse d'ail ») sont
  retirés avant la recherche ; comptés dans la similarité, ils la faisaient tomber
  sous le seuil et masquaient des correspondances évidentes
- **Alias relus** : `IngredientMatcherService` cherche l'exact sur le nom *et* sur les
  alias — sans quoi les associations confirmées à la main ne serviraient jamais
- **Comportement** :
  - Match exact → lien automatique, avec « Choisir un autre » si l'IA s'est trompée
  - Match approximatif → affiché à l'admin pour confirmation ou rejet
  - Aucun match → « Chercher » (recherche manuelle dans le catalogue, `GET /ingredients/search`)
    ou « Créer » → sidebar `quick_create`
  - Toute association manuelle enregistre le nom IA en alias : l'import suivant la retrouve seul

### Conversion d'unités : service dédié avec table exhaustive
- **Cas automatiques** (même `unit_group`) :

| Unité IA | Base | Facteur | unit_group |
|---|---|---|---|
| g | g | ×1 | mass |
| kg | g | ×1000 | mass |
| ml | ml | ×1 | volume |
| cl | ml | ×10 | volume |
| dl | ml | ×100 | volume |
| L | ml | ×1000 | volume |
| càc | cac | ×1 | spoon |
| càs | cac | ×3 | spoon |
| nil / pièce | piece | ×1 | count |

- **Cas manuel** : unité IA incompatible avec le `unit_group` de l'ingrédient (ex: "2 càs de beurre" alors que beurre est `mass`) → champ de saisie manuelle affiché à l'admin

### Page brouillons : route séparée `/recipe_drafts`
- Accessible uniquement à l'admin
- Lien dans le header avec badge compteur : "Brouillons (N)"
- Actions disponibles : consulter, éditer, publier, supprimer

---

## Modèle de données — changements

### Migration sur `recipes`

```ruby
add_column :recipes, :status, :integer, default: 1, null: false  # 1 = published
add_column :recipes, :source_type, :string   # "url", "photo", "manual"
add_column :recipes, :ai_raw_data, :jsonb    # réponse brute Claude pour debug

add_index :recipes, :status
```

> `default: 1` (published) pour ne pas impacter les recettes existantes.

### Mise à jour `Recipe` model

```ruby
enum :status, { draft: 0, published: 1 }, default: :published

scope :published, -> { where(status: :published) }
scope :draft, -> { where(status: :draft) }
```

### Mise à jour `RecipePolicy::Scope`

```ruby
class Scope < ApplicationPolicy::Scope
  def resolve
    user&.admin? ? scope.all : scope.where(status: :published)
  end
end
```

### Mise à jour `RecipePolicy` — nouvelles actions

```ruby
def import?
  user&.admin?
end

def publish?
  user&.admin?
end

def import_preview?
  user&.admin?
end
```

### Gardes à ajouter sur les actions existantes

- `add_to_menu` : refuser si `recipe.draft?`
- `toggle_in_draft` : refuser si `recipe.draft?`
- `toggle_favorite` : refuser si `recipe.draft?`

---

## Schéma JSON — extraction Claude API

Prompt à envoyer à Claude Sonnet pour obtenir un JSON strict correspondant au modèle `Recipe` :

```json
{
  "name": "Quiche lorraine",
  "description": "Description courte et appétissante de la recette.",
  "default_servings": 4,
  "prep_time_minutes": 20,
  "cook_time_minutes": 40,
  "total_time_minutes": null,
  "difficulty": "facile",
  "diet": "omnivore",
  "appliance": "four",
  "instructions": "1. Préchauffer le four à 180°C.\n2. Faire revenir les lardons...",
  "suggested_tags": ["entrée", "rapide", "fromage"],
  "ingredients": [
    { "name": "lardons fumés", "quantity": 200, "unit": "g" },
    { "name": "crème fraîche épaisse", "quantity": 20, "unit": "cl" },
    { "name": "oeufs", "quantity": 3, "unit": null }
  ]
}
```

**Règles dans le prompt :**
- `difficulty` : uniquement `"facile"`, `"moyen"`, `"difficile"` ou `null`
- `diet` : uniquement `"omnivore"`, `"vegetarien"`, `"vegan"`, `"pescetarien"`
- `total_time_minutes` : rempli uniquement si prep + cook ne sont pas distinguables dans la source
- `prep_time_minutes` / `cook_time_minutes` : `null` si non renseignés séparément
- `unit` : utiliser les unités telles qu'écrites dans la recette (g, kg, ml, cl, L, càc, càs, ou null si pièces)
- `instructions` : texte complet des étapes, numérotées, séparées par `\n`
- `suggested_tags` : suggestions basées sur le contenu (type de plat, cuisine, régime...)
- Ne jamais inventer d'information absente de la source

**Pour l'import photo** : l'image est envoyée en base64 dans la requête vision Claude.

**Pour l'import URL** :
1. Tenter d'abord le parsing `schema.org/Recipe` (JSON-LD dans le HTML) — gratuit et déterministe
2. Si absent → envoyer le texte extrait de la page à Claude pour structuration

---

## Plan d'implémentation — Phases

### Phase 1 — Infrastructure base (prérequis de tout le reste)

- [ ] Migration : `status`, `source_type`, `ai_raw_data` sur `recipes`
- [ ] Enum `status` + scopes `published` / `draft` dans `Recipe`
- [ ] Mise à jour `RecipePolicy::Scope` (filtre published pour non-admins)
- [ ] Gardes sur `add_to_menu`, `toggle_in_draft`, `toggle_favorite`
- [ ] Lien "Brouillons (N)" dans le header (admin uniquement)
- [ ] Vérifier que les vues existantes (catalogue, menu) ne sont pas impactées

### Phase 2 — Services métier

- [ ] Ajouter gem `anthropic` (ou appel HTTP direct) dans Gemfile
- [ ] `RecipeExtractorService` :
  - méthode `from_url(url)` : tente schema.org → fallback Claude
  - méthode `from_photo(image_base64)` : appel Claude Vision
  - retourne le JSON structuré ou lève une exception métier
- [ ] `UnitConversionService` :
  - méthode `convert(quantity, from_unit, ingredient)` → `quantity_base` ou `nil` si incompatible
  - table de conversion exhaustive (voir tableau ci-dessus)
- [ ] `IngredientMatcherService` :
  - méthode `match(name)` → `{ exact: Ingredient, fuzzy: [Ingredient], none: true }`
  - utilise la recherche trigram existante

### Phase 3 — Import (saisie de la source)

- [ ] Routes :
  ```ruby
  resources :recipe_imports, only: [:new, :create]
  resources :recipe_drafts, only: [:index, :show, :destroy]
  ```
- [ ] `RecipeImportPolicy` et `RecipeDraftPolicy` (admin only)
- [ ] `RecipeImportsController#new` : formulaire de choix (URL ou photo)
- [ ] `RecipeImportsController#create` :
  - appelle `RecipeExtractorService`
  - en cas d'échec : flash erreur + redirect vers `new`
  - en cas de succès : crée `Recipe` en `draft` avec données extraites + `ai_raw_data` → redirect vers `edit`
- [ ] Vue `recipe_imports/new` : deux onglets/options (URL / Photo)

### Phase 4 — Review form (le plus complexe)

- [ ] Réutiliser le formulaire `recipes/edit` existant (déjà admin-only)
- [ ] Ajouter un encart "Ingrédients extraits par l'IA" en sidebar droite :
  - Rappel du nombre de personnes en en-tête
  - Tableau : nom IA | quantité | unité | statut | action
  - Statuts : ✅ trouvé exact / ⚠️ match approximatif / ❌ non trouvé
  - Action ✅ : bouton "Ajouter à la recette" → calcule `quantity_base` via `UnitConversionService` → injecte dans le formulaire de préparations
  - Action ⚠️ : affiche le nom DB proposé + bouton "Confirmer" (ajoute alias) + bouton "Créer à la place"
  - Action ❌ : bouton "Créer" → ouvre sidebar `quick_create` existante
  - Si unités incompatibles : champ manuel `quantity_base` affiché
- [ ] Stimulus controller `recipe-import-panel` pour gérer les interactions
- [ ] Turbo Frame pour la création d'ingrédient inline (réutiliser `quick_create`)
- [ ] Bouton "Ajouter alias" : `PATCH /ingredients/:id` avec le nouveau alias
- [ ] Bouton "Publier la recette" : action `publish` → `recipe.published!` → redirect catalogue

### Phase 5 — Polish et sécurité

- [ ] Détection de doublons : avant publication, vérifier si une recette de même nom existe déjà (trigram) → warning à l'admin (pas un blocage)
- [ ] Gestion des tags suggérés : les `suggested_tags` de l'IA sont affichés comme suggestions cliquables dans le formulaire
- [ ] Nettoyage : prévoir une tâche rake pour supprimer les drafts de plus de 30 jours sans activité
- [ ] Tests : services `RecipeExtractorService`, `UnitConversionService`, `IngredientMatcherService`

---

## Points d'attention pour le codage

### Sur le formulaire de review
- Le formulaire est le **même** que `recipes/edit` — ne pas créer un nouveau formulaire, juste étendre la vue existante avec l'encart IA
- L'encart est visible uniquement si `recipe.draft?` et `recipe.ai_raw_data.present?`
- Une fois un ingrédient "ajouté" depuis l'encart, il disparaît de l'encart et apparaît dans la liste des préparations

### Sur les ingrédients
- Ne jamais créer un ingrédient en doublon — vérifier `Ingredient.find_by(name: name.downcase.strip)` avant tout `quick_create`
- Les alias sont stockés en JSONB (`aliases` sur `Ingredient`) — vérifier le format exact avant d'écrire
- La `quantity_base` est en `decimal(10,3)` — arrondir proprement lors de la conversion

### Sur la sécurité API
- La clé Claude API est dans les variables d'environnement (`ENV["ANTHROPIC_API_KEY"]`), jamais en dur
- Timeout à configurer sur l'appel API (les photos peuvent être lentes)
- Logger l'appel (durée, source_type) sans logger la clé ni le contenu de la photo

### Sur le scope Pundit
- Le changement de `RecipePolicy::Scope` impacte **toutes** les vues qui utilisent `policy_scope(Recipe)` — vérifier chaque occurrence dans le code avant de déployer

### Sur la compatibilité menus
- Les scopes de génération de menu (`Recipe.compatible_with`, `Recipe.seasonal_for_month`) doivent opérer **après** le filtre published — chaîner les scopes dans le bon ordre
