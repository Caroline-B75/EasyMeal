# Instructions Copilot pour EasyMeal

## Exigences globales de qualité du code

Ces exigences s'appliquent a tout le code du projet, sans exception :

- Produire un code propre, fiable, robuste et maintenable.
- Commenter le code clairement et simplement lorsque cela aide a comprendre l'intention, les choix techniques ou les cas particuliers.
- Respecter le principe DRY : extraire et mutualiser la logique commune au lieu de dupliquer du code.
- Supprimer tout code mort : aucune methode, classe, variable, vue, route, partial, constante ou dependance inutilisee ne doit rester dans le projet.
- Respecter systematiquement les meilleures pratiques du langage, du framework et de l'architecture existante du projet.

## ⚠️ RÈGLE ABSOLUE - COMMANDES CONSOLE

**INTERDICTION TOTALE** d'exécuter des commandes Rails console (`rails console`, `rails c`) ou toute commande interactive en console.

- ❌ **NE JAMAIS** lancer `rails console`
- ❌ **NE JAMAIS** lancer `rails c`
- ❌ **NE JAMAIS** exécuter de code Ruby en console interactive
- ✅ L'utilisateur exécute LUI-MÊME toutes les commandes console
- ✅ Tu peux SUGGÉRER des commandes à exécuter, mais JAMAIS les lancer

**Exception** : Tu peux utiliser `run_in_terminal` uniquement pour :

- Commandes non-interactives (migrations, seeds, tests, etc.)
- Commandes bash/système (ls, cat, grep, etc.)
- Build, compilation, installation de gems

## ⚠️ RÈGLE ABSOLUE - ENVIRONNEMENT D'EXÉCUTION

L'application tourne sous **Ubuntu/WSL** (`/mnt/c/Caroline/easymeal`), **pas sous Windows PowerShell**.

- ❌ **NE JAMAIS** essayer de lancer `ruby`, `bundle`, `rails` depuis PowerShell — ils ne sont pas dans le PATH Windows
- ❌ **NE JAMAIS** tenter `wsl -e bash -c "..."` pour exécuter des commandes Rails
- ✅ **TOUJOURS demander à l'utilisateur** de lancer les commandes dans son terminal Ubuntu
- ✅ Formuler la demande clairement avec la commande exacte à copier-coller

**Exemple correct :**

> Peux-tu lancer dans ton terminal Ubuntu :
>
> ```bash
> cd /mnt/c/Caroline/easymeal && bundle exec rails db:migrate
> ```

## Charte Graphique EasyMeal — Slate Craft Premium

### Principe directeur

Interface premium de type éditorial/magazine culinaire. Anthracite comme couleur principale, ambre comme seul accent coloré (saison + notations), typographie sérieuse et aérée.

### Palette de Couleurs

**TOUJOURS utiliser cette palette pour tous les éléments visuels du projet :**

| Variable                | Valeur    | Usage                                             |
| ----------------------- | --------- | ------------------------------------------------- |
| `--color-primary`       | `#1C1917` | CTA principaux, boutons d'action, avatar          |
| `--color-accent`        | `#FBBF24` | Badge "de saison", étoiles de notation UNIQUEMENT |
| `--color-success-light` | `#ECFCCB` | Badge végétarien / vegan (fond)                   |
| `--color-bg-main`       | `#F8F7F4` | Fond principal                                    |
| `--color-bg-white`      | `#FFFFFF` | Cards, formulaires                                |

### Application des Couleurs

- **Boutons primaires** : Fond anthracite (#1C1917), hover gris foncé (#44403C)
- **Boutons secondaires** : Fond gris clair (#F1F0EC), texte (#44403C), bordure (#E7E5E4)
- **Liens** : Gris moyen (#78716C), hover anthracite (#1C1917)
- **Badges** : Fond gris clair avec bordure fine, ou sémantique (vert/bleu/ambre)
- **Fonds** : Blanc chaud (#F8F7F4) global, gris clair (#F1F0EC) pour zones/cartes
- **Bordures** : Gris clair (#E7E5E4), fine (0.5px)
- **Textes** : Anthracite (#1C1917) pour titres, gris (#78716C) pour secondaire
- **Focus/active states** : Anthracite avec opacity réduite

### Design System - Composants

#### Boutons

- **Border-radius** : `4px` pour TOUS les boutons (jamais de pills à 25px)
- **Taille minimale** : 44x44px pour la navigation tactile (mobile)
- **Transition** : 0.15s sur hover pour feedback visuel fluide

#### Badges

- **Border-radius** : `2px`
- **Font-size** : `0.75rem`
- **Font-weight** : `500`

#### Cards

- **Border-radius** : `6px`
- **box-shadow** : `none` (bordure fine uniquement)

#### Variables CSS

- **OBLIGATOIRE** : Toutes les couleurs doivent être définies via des variables CSS dans `variables.css`
- Centralise la gestion des couleurs pour faciliter les modifications globales
- Permet une cohérence visuelle sur tout le projet

### Règles strictes

- Le rouge `#D73A49` et l'orange `#FF9E4D` ne sont plus utilisés comme couleurs d'interface
- L'ambre `#FBBF24` est réservé exclusivement à : badge "de saison" + étoiles de notation
- Les séparateurs de section sont `0.5px solid var(--color-border)` + label uppercase 11px letterspaced
- Les icônes d'action (edit/delete) sont en `var(--color-ink-4)`, jamais en rouge
- Le logo EasyMeal (image + typographie) est conservé tel quel, sans modification

**Note** : Cette charte doit être utilisée de manière cohérente dans tous les fichiers CSS, composants et nouvelles fonctionnalités.

## Principes de Codage à Respecter

### 1. Simplicité et Clarté

- **Toujours privilégier un code simple et lisible** plutôt qu'un code complexe ou "clever"
- Utiliser des noms de variables et de méthodes **explicites et descriptifs**
- Éviter les abréviations obscures
- Une fonction = une responsabilité

### 2. Commentaires Utiles

- Ajouter des **commentaires pour expliquer le "pourquoi"**, pas le "quoi"
- Documenter les choix techniques non évidents
- Commenter les cas particuliers et les edge cases
- Utiliser des commentaires pour structurer le code en sections logiques

### 3. Principes DRY (Don't Repeat Yourself)

- **Ne jamais dupliquer du code** : extraire dans des méthodes/fonctions réutilisables
- Créer des helpers, des concerns ou des partials pour le code répétitif
- Mutualiser la logique commune

### 4. Refactorisation Continue

- Proposer systématiquement du **code refactorisé et optimisé**
- Identifier et éliminer le code mort
- Simplifier les conditions complexes
- Extraire les méthodes trop longues (max 15-20 lignes)

### 5. Conventions Rails

- Respecter les **conventions Ruby on Rails** (REST, naming, structure)
- Utiliser les helpers Rails appropriés
- Suivre le pattern MVC strictement
- Privilégier les associations Active Record

### 6. Tests et Qualité

- Suggérer des tests si pertinent
- Penser à la maintenabilité du code
- Anticiper les cas d'erreur

### 7. Performance

- Éviter les N+1 queries (utiliser `includes`, `joins`)
- Optimiser les requêtes SQL
- Limiter les appels à la base de données

### 8. Sécurité

- Toujours valider et sanitiser les entrées utilisateur
- Utiliser les protections Rails (CSRF, SQL injection, XSS)
- Ne jamais exposer de données sensibles

### 9. Responsive Design (Mobile-First)

- **L'application DOIT être entièrement responsive** pour mobile, tablette et desktop
- Adopter une approche **Mobile-First** : concevoir d'abord pour mobile, puis adapter pour tablettes et desktop
- Utiliser des **media queries** CSS pour les différents breakpoints :
  - Mobile : < 768px
  - Tablette : 768px - 1024px
  - Desktop : > 1024px
- Prévoir des **layouts adaptés** : colonnes empilées sur mobile, grilles sur desktop
- Optimiser la **navigation tactile** : boutons suffisamment grands (min 44x44px), espacement adapté
- Adapter les **tableaux** pour mobile : passer en mode carte/liste ou scroll horizontal
- Tester systématiquement sur **différents formats d'écran**
- L'utilisateur doit pouvoir utiliser toutes les fonctionnalités sur téléphone

### 10. Solutions Natives et Librairies

- **TOUJOURS privilégier les solutions natives** avec les outils déjà présents dans le projet
- Vérifier d'abord ce qui est disponible dans Rails 7, Stimulus, Turbo, Hotwire
- Utiliser les controllers Stimulus plutôt que du JavaScript vanilla inline
- Exploiter les capacités de Turbo (Turbo Frames, Turbo Streams) avant d'ajouter du code custom

#### Avant d'ajouter une nouvelle gem/librairie :

1. **Vérifier** si Rails/Stimulus/Turbo ne propose pas déjà une solution
2. **Rechercher** dans la documentation officielle Rails et Hotwire
3. Si vraiment nécessaire, proposer des gems qui respectent ces critères :
   - ✅ **Largement utilisées** (> 1000 stars GitHub, nombreux téléchargements)
   - ✅ **Activement maintenues** (commit récent < 6 mois)
   - ✅ **Compatible Rails 7+**
   - ✅ **Documentation claire et complète**
   - ✅ **Communauté active** (issues résolues rapidement)
   - ✅ **Simple à configurer** (setup minimal)

#### Gems recommandées par catégorie :

**UI/UX :**

- `view_component` : Composants réutilisables
- `pagy` : Pagination (déjà installé ✅)

**Formulaires :**

- `simple_form` : Formulaires Rails (déjà installé ✅)

**Authentification :**

- `devise` : Auth complète (déjà installé ✅)
- `pundit` : Autorisation (déjà installé ✅)

**Background Jobs :**

- `sidekiq` : Jobs asynchrones performants
- `good_job` : Alternative avec PostgreSQL

**Upload de fichiers :**

- Active Storage (natif Rails ✅)
- `shrine` : Alternative puissante

**API :**

- `jbuilder` : JSON natif Rails
- `blueprinter` : Serialization moderne

#### Éviter :

- ❌ jQuery (utiliser Stimulus)
- ❌ Gems abandonnées ou non maintenues
- ❌ Solutions complexes quand une solution simple existe
- ❌ JavaScript vanilla inline répétitif (créer un controller Stimulus)

### 11. Architecture CSS et Composants

#### Organisation CSS :

- **Séparer les CSS par domaine fonctionnel** :
  - `layouts.css` : Navigation, headers, footers, structure globale réutilisable
  - `components.css` : Composants UI réutilisables (boutons, cards, badges, modals)
  - `[resource].css` : Styles spécifiques à une ressource (ex: `ingredients.css`)
  - `responsive.css` : Media queries et adaptations mobile/tablet/desktop

#### Composants Réutilisables :

- **Créer une bibliothèque de composants** pour éviter la duplication
- Utiliser des **classes CSS utilitaires** cohérentes :
  - `.card`, `.card-compact`, `.card-header`
  - `.btn`, `.btn-primary`, `.btn-secondary`, `.btn-link`
  - `.badge`, `.badge-orange`, `.badge-beige`
  - `.icon-btn`, `.icon-btn-edit`, `.icon-btn-delete`
- **Documenter les composants** avec des commentaires clairs
- Privilégier la composition de classes plutôt que la duplication de styles

#### Conventions de Nommage CSS :

- **BEM (Block Element Modifier)** ou approche similaire pour la clarté
- Noms **descriptifs et cohérents** (ex: `.ingredient-card` plutôt que `.ing-c`)
- **Variables CSS** pour les couleurs, espacements, breakpoints récurrents

### 12. Templates HAML

- **TOUTES les vues DOIVENT être en HAML** (`.html.haml`)
- HAML est plus concis, lisible et maintenable qu'ERB
- Respecter l'indentation stricte de HAML (2 espaces)
- Utiliser les helpers Rails directement sans `<% %>`
- Privilégier les partials HAML pour la réutilisabilité

#### Exemple de conversion ERB → HAML :

```erb
<!-- ❌ ERB -->
<div class="card">
  <h2><%= @ingredient.name %></h2>
  <%= link_to "Edit", edit_ingredient_path(@ingredient), class: "btn" %>
</div>
```

```haml
-# ✅ HAML
.card
  %h2= @ingredient.name
  = link_to "Edit", edit_ingredient_path(@ingredient), class: "btn"
```

## Style de Réponse Attendu

- **Expliquer brièvement** les choix techniques importants
- Proposer des **alternatives** quand c'est pertinent
- Signaler les **potentiels problèmes** ou améliorations futures
- Être **concis** mais complet

## Exemple de Code Attendu

```ruby
# ❌ MAUVAIS
def process(d)
  # calcul
  r = d.map { |x| x * 2 }.select { |x| x > 10 }
  r
end

# ✅ BON
# Filtre et transforme les données selon les critères métier
def process_eligible_values(data)
  data
    .map { |value| double_value(value) }
    .select { |value| above_threshold?(value) }
end

private

def double_value(value)
  value * 2
end

def above_threshold?(value)
  value > MINIMUM_THRESHOLD
end
```

## Architecture Menus — Règles absolues

### Pattern retenu : Draft persisté en base (status enum)

Un brouillon de menu EST un menu. Pas de PORO en session.

```ruby
# Menu possède un enum status
enum :status, { draft: 0, active: 1 }, prefix: true
# + colonnes : diet (integer), default_people (integer)
```

**À ne JAMAIS faire :**

- ❌ Stocker un MenuDraft en `session[:menu_draft]`
- ❌ Créer un PORO `MenuDraft` ou `Meal` pour représenter un menu temporaire
- ❌ Créer un `DraftController` séparé
- ❌ Créer un service `DraftActions` opérant sur un objet en mémoire

**À toujours faire :**

- ✅ Créer `Menu(status: :draft)` en base dès la génération
- ✅ Toutes les mutations (add/remove/replace/update_people) opèrent sur des `MenuRecipe` en base
- ✅ Répondre en **Turbo Streams** pour toutes les actions de personnalisation
- ✅ Activer le menu avec `menu.activate!` → déclenche `Groceries::BuildForMenuService`

### Hiérarchie des régimes alimentaires

```ruby
# Toujours utiliser Recipe.compatible_with(diet), jamais Recipe.where(diet: diet)
# vegan ⊂ végétarien ⊂ omnivore ; pescétarien ⊂ omnivore
DIET_COMPATIBILITY = {
  "omnivore"    => %w[omnivore vegetarien vegan pescetarien],
  "pescetarien" => %w[vegetarien vegan pescetarien],
  "vegetarien"  => %w[vegetarien vegan],
  "vegan"       => %w[vegan]
}.freeze
```

### Services menus (nommage officiel)

| Service                           | Responsabilité                                        |
| --------------------------------- | ----------------------------------------------------- |
| `Menus::GenerateService`          | Crée Menu(draft) puis délègue la composition          |
| `Menus::ComposeMealsService`      | (Re)compose les repas selon une commande `MealCounts` |
| `Menus::SeasonalDrawService`      | Tirage d'un pool, recettes de saison d'abord          |
| `Menus::CandidatePickerService`   | Tire 1 recette de remplacement dans le bon moment     |
| `Menus::ReplaceMealService`       | Remplace 1 MenuRecipe (conserve sa place et son moment) |
| `Menus::ToggleDraftRecipeService` | Ajoute/retire une recette du brouillon (catalogue)    |
| `Groceries::BuildForMenuService`  | Génère/régénère les GroceryItems(:generated)          |

Le pool épuisé n'est une erreur QUE pour un remplacement (`Menus::NoCandidatesError`). À la
génération, un pool trop maigre remplit ce qu'il peut : le manque s'affiche dans le brouillon
(`Menu#missing_meal_counts`), il n'échoue jamais (UC7).

---

## Technologies du Projet

- **Framework** : Ruby on Rails 7.x
- **Base de données** : PostgreSQL (voir config/database.yml)
- **Frontend** : HAML, Stimulus, CSS modulaire
- **Authentification** : Devise
- **Autorisation** : Pundit
- **Pagination** : Pagy
- **Tests** : RSpec

---

**Note** : Ces instructions s'appliquent à **toutes les requêtes** dans ce projet, sans exception.
