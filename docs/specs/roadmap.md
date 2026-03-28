# 🔍 ANALYSE COMPLÈTE DU PROJET EASYMEAL

## ❓ QUESTIONS À RÉSOUDRE AVANT DÉMARRAGE

### Fonctionnelles

1. **Granularité des tags** : Liste fermée ou ouverte ? (Recommandation: semi-fermée avec seed admin)
2. **Unités de conversion complexes** : Gestion des conversions densité (g ↔ ml pour certains ingrédients) en V1 ou reporter ?
3. **Régénération liste de courses** : Confirmer que les edits utilisateur sur lignes `generated` sont perdus (specs UC3 dit oui)
4. **Photos recettes** : Obligatoires ou optionnelles ? Image par défaut ?
5. **Validation email** : Activer `:confirmable` Devise dès V1 ? (Recommandé pour éviter spam)

### Techniques

1. **Session vs Redis pour MenuDraft** : Session suffisant pour V1 ? (Recommandation: oui, Redis si multi-devices)
2. **Matérialisation rating_avg** : En V1 ou calculé à la volée ? (Recommandation: calculé puis optimiser si besoin)
3. **Tests système** : Capybara + Selenium ou juste tests request/feature RSpec ?
4. **CI/CD** : GitHub Actions configuré dès le début ?

## 📦 DÉPENDANCES MANQUANTES

### Fichiers de configuration à créer

- `app/policies/application_policy.rb` (Pundit)

---

# 🗺️ ROADMAP RAILS DÉTAILLÉE

## 📋 LÉGENDE

- **Temps** : estimations pour développeur Rails intermédiaire
- **Difficulté** : ⭐ Facile | ⭐⭐ Moyen | ⭐⭐⭐ Complexe | ⭐⭐⭐⭐ Avancé

---

## PHASE 0 : SETUP & CONFIGURATION (3-4h)

**Difficulté**: ⭐⭐

### 0.1 - Configuration manquante (1h30) -> done

1. Ajouter `gem "redis"` au Gemfile + `bundle install` -> done
2. Créer `config/storage.yml` : -> done

```yaml
cloudinary: -> done
  service: Cloudinary
  cloud_name: <%= ENV['CLOUDINARY_CLOUD_NAME'] %>
  api_key: <%= ENV['CLOUDINARY_API_KEY'] %>
  api_secret: <%= ENV['CLOUDINARY_API_SECRET'] %>
```

3. Modifier production.rb : `config.active_storage.service = :cloudinary` -> done
4. Créer `config/initializers/pagy.rb` -> done
5. Installer Pundit : `rails g pundit:install` -> done

### 0.2 - Setup Testing (1h) -> ?????????????????????

1. Configurer RSpec avec shoulda-matchers -> ?????????????????????
2. Créer helpers de test (sign_in, factory helpers) -> ?????????????????????
3. Configurer Capybara pour tests système -> ?????????????????????

### 0.3 - Configuration User étendue (30min)

1. Migration pour ajouter champs à User :
   - `admin:boolean` (default: false, index)
   - `default_diet:integer` (enum)
   - `default_people:integer` (default: 4)
2. Mettre à jour modèle User avec validations
3. Seed admin initial

---

## PHASE 1 : MODÈLES FONDAMENTAUX (8-10h)

**Ordre crucial** : Ingrédient → Tag → Recette → Préparation

### 1.1 - Modèle Ingredient (2h) ⭐⭐

**Priorité**: CRITIQUE - base de tout le système

**Migration** :

```ruby
create_table :ingredients do |t|
  t.string :name, null: false, index: true
  t.integer :category, null: false # enum (rayon)
  t.integer :unit_group, null: false # enum (mass/volume/count/spoon)
  t.string :base_unit, null: false # 'g', 'ml', 'piece', 'cac'
  t.jsonb :aliases, default: [] # ['tomates', 'tomate cerise']
  t.integer :season_months, array: true, default: [] # [6,7,8] = juin-août
  t.timestamps
end
add_index :ingredients, :aliases, using: :gin
```

**Modèle** :

- Enums : `category` (20+ rayons), `unit_group`
- Validations : name presence/uniqueness, category/unit_group presence
- Scopes : `seasonal_for(month)`, `in_category(category)`

**Tests** : 15+ specs (validations, enums, scopes)

### 1.2 - Modèle Tag (1h) ⭐

**Migration** :

```ruby
create_table :tags do |t|
  t.string :name, null: false, index: {unique: true}
  t.timestamps
end
```

**Modèle** : Simple, validation name uniqueness

### 1.3 - Modèle Recipe (3h) ⭐⭐⭐

**Dépendances** : Aucune (mais utilisera tags et ingredients via associations)

**Migration** :

```ruby
create_table :recipes do |t|
  t.string :name, null: false, index: true
  t.text :description
  t.integer :default_servings, null: false, default: 4
  t.integer :prep_time_minutes
  t.integer :cook_time_minutes
  t.integer :diet, null: false, default: 0 # enum
  t.integer :difficulty # enum optionnel
  t.integer :price_level # enum optionnel
  t.string :appliance # 'four', 'robot', etc.
  t.text :steps # JSON ou texte structuré
  t.string :source_url
  t.timestamps
end
```

**Modèle** :

- Enum diet: `{omnivore: 0, vegetarien: 1, vegan: 2, pescetarien: 3}`
- `has_one_attached :photo`
- Validations: name, default_servings >= 1, diet presence
- Méthodes: `total_time`, `seasonal_for_month?`

**Tests** : 20+ specs

### 1.4 - Table de liaison RecipeTag (30min) ⭐

```ruby
create_table :recipe_tags do |t|
  t.references :recipe, null: false, foreign_key: true
  t.references :tag, null: false, foreign_key: true
  t.timestamps
end
add_index :recipe_tags, [:recipe_id, :tag_id], unique: true
```

### 1.5 - Modèle Preparation (2h) ⭐⭐

**Dépendances** : Recipe ET Ingredient

**Migration** :

```ruby
create_table :preparations do |t|
  t.references :recipe, null: false, foreign_key: true
  t.references :ingredient, null: false, foreign_key: true
  t.decimal :quantity_base, precision: 10, scale: 3, null: false
  t.integer :order_index, default: 0
  t.timestamps
end
add_index :preparations, [:recipe_id, :ingredient_id]
```

**Modèle** :

- Validations: quantity_base > 0
- Delegate: `unit_group`, `base_unit` to ingredient
- Méthode: `humanized_quantity(factor = 1)`

**Tests** : 10+ specs (conversions, humanisation)

---

## PHASE 2 : SYSTÈME DE MENUS (10-12h)

### 2.1 - Modèle Menu (2h) ⭐⭐

**Migration** :

```ruby
create_table :menus do |t|
  t.references :user, null: false, foreign_key: true, index: true
  t.string :name
  t.integer :diet, null: false
  t.integer :default_people, null: false, default: 4
  t.date :week_start_date
  t.timestamps
end
```

**Modèle** :

- Validations: diet, default_people >= 1
- `has_many :menu_recipes, dependent: :destroy`
- `has_many :recipes, through: :menu_recipes`

### 2.2 - Modèle MenuRecipe (1h30) ⭐⭐

```ruby
create_table :menu_recipes do |t|
  t.references :menu, null: false, foreign_key: true
  t.references :recipe, null: false, foreign_key: true
  t.integer :number_of_people, null: false, default: 4
  t.integer :position, default: 0
  t.timestamps
end
add_index :menu_recipes, [:menu_id, :recipe_id]
```

**Validations** : number_of_people >= 1

### 2.3 - MenuDraft (PORO - Plain Old Ruby Object) (3h) ⭐⭐⭐

**Fichier** : `app/models/menu_draft.rb`

Classe non-persistée pour UC1 :

- Attributs: diet, default_people, meals (array de Meal structs)
- Meal = Struct.new(:recipe, :number_of_people, :seasonal)
- Sérialisable en session
- Méthodes: `add_meal`, `remove_meal`, `replace_meal`, `update_people`

**Tests** : 15+ specs (mutations, validations non-duplication)

### 2.4 - Service Menus::Generate (4h) ⭐⭐⭐

**Fichier** : `app/services/menus/generate.rb`

Logique UC1 :

- Sélection recipes compatibles diet
- Priorité saisonnalité (2 pools : saison / hors saison)
- Algorithme sans doublon
- Retourne MenuDraft

**Tests** : 25+ specs (edge cases, saisons, épuisement)

### 2.5 - Service Menus::DraftActions (2h) ⭐⭐⭐

Mutations draft : `add_random`, `add_manual`, `replace`, `remove`, `update_people`

---

## PHASE 3 : LISTE DE COURSES (8-10h)

### 3.1 - Modèle GroceryItem (3h) ⭐⭐⭐

```ruby
create_table :grocery_items do |t|
  t.references :menu, null: false, foreign_key: true
  t.references :ingredient, null: true, foreign_key: true
  t.references :menu_recipe, null: true, foreign_key: true
  t.string :name # si custom sans ingredient_id
  t.decimal :quantity_base, precision: 10, scale: 3, null: false
  t.string :unit_display
  t.integer :unit_group, null: false
  t.integer :category, null: false
  t.integer :source, null: false, default: 0 # enum: generated/manual
  t.boolean :checked, default: false
  t.timestamps
end
add_index :grocery_items, [:menu_id, :ingredient_id]
add_index :grocery_items, :menu_id
```

**Enums** : `source: {generated: 0, manual: 1}`

### 3.2 - Service GroceryLists::Generate (4h) ⭐⭐⭐⭐

**Fichier** : `app/services/grocery_lists/generate.rb`

Logique UC3 :

- Parcourt menu_recipes
- Calcule facteur portions
- Agrège par ingredient + unit_group
- Humanise quantités (kg/L/càs+càc/pincée)
- Groupe par category (rayon)

**Complexité** : Conversions spoons (arrondi 0.25 càc)

**Tests** : 30+ specs (conversions, agrégation, humanisation)

### 3.3 - Service GroceryLists::Regenerate (2h) ⭐⭐⭐

Option A (UC3) :

- Supprime items `source: generated`
- Conserve items `source: manual`
- Régénère generated

**Tests** : 15+ specs

### 3.4 - Service pour ajout manuel ingrédient (1h) ⭐⭐

Admin uniquement si création, sinon custom

---

## PHASE 4 : INTERACTIONS SOCIALES (6-8h)

### 4.1 - Modèle FavoriteRecipe (1h30) ⭐

```ruby
create_table :favorite_recipes do |t|
  t.references :user, null: false, foreign_key: true
  t.references :recipe, null: false, foreign_key: true
  t.timestamps
end
add_index :favorite_recipes, [:user_id, :recipe_id], unique: true
```

### 4.2 - Modèle Review (2h) ⭐⭐

```ruby
create_table :reviews do |t|
  t.references :user, null: false, foreign_key: true
  t.references :recipe, null: false, foreign_key: true
  t.integer :rating, null: false # 1..5
  t.text :content
  t.timestamps
end
add_index :reviews, [:user_id, :recipe_id], unique: true
add_index :reviews, :recipe_id
```

**Validations** : rating inclusion 1..5

### 4.3 - Counter caches & rating_avg (2h) ⭐⭐

- Ajouter `reviews_count` à recipes (migration)
- Méthode ou scope `rating_avg` (moyenne dynamique V1)

**Tests** : 10+ specs

### 4.4 - Service Recipes::ScaleIngredients (2h) ⭐⭐

Pour UC4 : recalcul quantités selon servings

---

## PHASE 5 : POLICIES PUNDIT (4-5h)

### 5.1 - ApplicationPolicy & inclusion (30min) ⭐

Déjà généré, inclusion dans ApplicationController

### 5.2 - Policies individuelles (3h) ⭐⭐

Créer dans `app/policies/` :

- `menu_policy.rb` (owner-only)
- `menu_recipe_policy.rb` (owner via menu)
- `grocery_item_policy.rb` (owner via menu)
- `ingredient_policy.rb` (create: admin, read: all)
- `recipe_policy.rb` (read: all)
- `favorite_recipe_policy.rb` (owner-only)
- `review_policy.rb` (owner-only, edit own)

**Tests** : 40+ specs policy

### 5.3 - Rescue Pundit errors (30min) ⭐

Dans ApplicationController : rescue `Pundit::NotAuthorizedError`

---

## PHASE 6 : CONTROLLERS & ROUTES (12-15h)

### 6.1 - MenusController (4h) ⭐⭐⭐

Routes :

```ruby
resources :menus do
  member do
    post :save_and_regenerate
  end
  resources :recipes, only: [:show], controller: 'menus/recipes'
end
```

Actions :

- `new` (form UC1)
- `preview` (POST - génère draft, stocke session)
- `create` (persiste draft)
- `show` (affiche menu avec possibilité édition)
- `update` (pour modifs)
- `save_and_regenerate` (UC2 → régénère liste)

### 6.2 - Menus::DraftController (3h) ⭐⭐⭐

Routes :

```ruby
namespace :menus do
  resource :draft, only: [] do
    post :add_random
    post :add_manual
    delete :remove_meal
    patch :replace_meal
    patch :update_meal_people
  end
end
```

Toutes actions manipulent session draft + Turbo Streams

### 6.3 - RecipesController (3h) ⭐⭐⭐

```ruby
resources :recipes, only: [:index, :show] do
  member do
    post :favorite
    delete :unfavorite
  end
end
```

- `index` : Ransack + Pagy (UC5)
- `show` : avec contexte menu optionnel (UC4)

### 6.4 - GroceryListsController (2h) ⭐⭐

```ruby
resources :menus do
  resource :grocery_list, only: [:show] do
    resources :items, only: [:create, :update, :destroy], controller: 'grocery_lists/items'
  end
end
```

- `show` : affiche liste groupée par rayon
- Items : CRUD pour édition

### 6.5 - ReviewsController (1h30) ⭐⭐

Nested sous recipes : `create`, `update`, `destroy`

### 6.6 - UsersController (profil) (1h) ⭐

`edit`, `update` pour préférences

---

## PHASE 7 : VUES HAML (15-18h)

### 7.1 - Layout & partials communs (2h) ⭐⭐

- `application.html.haml`
- `_navbar.html.haml` (avec menu user, admin badge)
- `_flash.html.haml`
- `_errors.html.haml` (affichage erreurs formulaire)

### 7.2 - Devise views (2h) ⭐

Convertir en Haml : login, signup, forgot password, edit profile

### 7.3 - Menus views (4h) ⭐⭐⭐

- `new.html.haml` (form génération UC1)
- `preview.html.haml` (draft avec cartes repas, actions personnalisation)
- `show.html.haml` (menu persisté, similar to preview)
- Partials : `_meal_card.html.haml`, `_add_meal_dropdown.html.haml`

### 7.4 - Recipes views (4h) ⭐⭐⭐

- `index.html.haml` (grille + filtres Ransack, UC5)
- `show.html.haml` (fiche détaillée UC4, avec contexte menu)
- Partials : `_recipe_card.html.haml`, `_filters_panel.html.haml`, `_ingredient_list.html.haml`

### 7.5 - GroceryLists views (3h) ⭐⭐⭐

- `show.html.haml` (liste par rayon avec checkboxes)
- `_add_item_modal.html.haml` (pop-up UC3 avec 3 chemins)
- Partials : `_grocery_section.html.haml`, `_item_row.html.haml`

### 7.6 - User profile (1h) ⭐

`users/edit.html.haml`

### 7.7 - Home & static (1h) ⭐

Landing page simple

---

## PHASE 8 : STIMULUS CONTROLLERS (8-10h)

### 8.1 - meal_people_controller.js (2h) ⭐⭐

Contrôles −/+ pour nombre de personnes par repas

### 8.2 - filters_controller.js (2h) ⭐⭐

Gestion filtres Ransack (chips, reset)

### 8.3 - grocery_item_controller.js (2h) ⭐⭐

Toggle checkbox, édition inline quantité

### 8.4 - add_item_modal_controller.js (2h) ⭐⭐⭐

Logique pop-up UC3 (switch admin, autocomplete ingrédients)

### 8.5 - favorite_controller.js (1h) ⭐

Toggle favori avec Turbo

### 8.6 - rating_controller.js (1h) ⭐

Sélection étoiles pour notation

---

## PHASE 9 : SCOPES & QUERY OBJECTS (4-5h)

### 9.1 - Recipe scopes (2h) ⭐⭐

- `seasonal_for(month)`
- `compatible_with(diet)`
- `with_ingredient_names(names)`
- `without_ingredient_names(names)`
- `with_total_time_lte(minutes)`

### 9.2 - Ransackers custom (1h30) ⭐⭐

Pour recherche texte sur aliases ingredients (jsonb)

### 9.3 - Query objects complexes (1h) ⭐⭐

`RecipeSearchQuery` si Ransack insuffisant

---

## PHASE 10 : SEEDS (6-8h)

### 10.1 - Seeds ingredients (3h) ⭐⭐⭐

**Timing** : AVANT recipes

100+ ingrédients avec :

- Categories (tous les rayons)
- Unit_groups corrects
- Season_months réalistes
- Aliases pertinents

**Fichier** : `db/seeds/ingredients.rb`

### 10.2 - Seeds tags (30min) ⭐

20-30 tags : rapide, végé, comfort food, asiatique, etc.

### 10.3 - Seeds recipes (3h) ⭐⭐⭐

**Timing** : APRÈS ingredients et tags

30-50 recettes variées :

- Tous diets
- Avec preparations (ingrédients + quantités)
- Tags pertinents
- Steps structurés
- Photos via seed ou URLs ActiveStorage

**Fichier** : `db/seeds/recipes.rb`

### 10.4 - Seeds users & demo data (1h) ⭐⭐

- Admin
- 2-3 users normaux
- Quelques menus
- Reviews/favoris

**Organisation** :

```ruby
# db/seeds.rb
load Rails.root.join('db', 'seeds', 'ingredients.rb')
load Rails.root.join('db', 'seeds', 'tags.rb')
load Rails.root.join('db', 'seeds', 'recipes.rb')
load Rails.root.join('db', 'seeds', 'users.rb')
```

---

## PHASE 11 : TESTS (20-25h parallèle au développement)

### 11.1 - Tests modèles (8h) ⭐⭐

- Validations, associations, scopes
- ~150 specs

### 11.2 - Tests services (6h) ⭐⭐⭐

- Génération menu, draft actions, grocery lists
- ~80 specs

### 11.3 - Tests policies (3h) ⭐

- Toutes les policies
- ~40 specs

### 11.4 - Tests controllers (5h) ⭐⭐

- Request specs pour toutes les actions
- ~60 specs

### 11.5 - Tests feature/système (5h) ⭐⭐⭐

- Scénarios Gherkin des 6 UC
- ~30 features

---

## PHASE 12 : OPTIMISATIONS & POLISH (6-8h)

### 12.1 - Index database (1h) ⭐

Vérifier tous les index nécessaires

### 12.2 - N+1 queries (2h) ⭐⭐

Bullet gem, includes/eager_load

### 12.3 - Images variants (1h) ⭐

Définir variants ActiveStorage (thumbnails, cards)

### 12.4 - I18n (2h) ⭐⭐

Externaliser strings dans `config/locales/fr.yml`

### 12.5 - Error pages (1h) ⭐

Styliser 404, 500, 422

### 12.6 - Turbo optimizations (1h) ⭐⭐

Turbo Streams pour actions draft/grocery

---

## PHASE 13 : DÉPLOIEMENT (4-5h)

### 13.1 - Credentials (1h) ⭐

Configurer CLOUDINARY, SECRET_KEY_BASE, etc.

### 13.2 - Docker build test (1h) ⭐⭐

Vérifier Dockerfile fonctionne

### 13.3 - Setup CI (2h) ⭐⭐

GitHub Actions : RSpec, Rubocop, Brakeman

### 13.4 - Deploy staging (1h) ⭐⭐

Heroku/Render/autre

---

# 📊 RÉCAPITULATIF

## Estimation totale : **110-140 heures** (14-18 jours à plein temps)

### Par difficulté :

- ⭐ Facile : 25h (23%)
- ⭐⭐ Moyen : 45h (41%)
- ⭐⭐⭐ Complexe : 30h (27%)
- ⭐⭐⭐⭐ Avancé : 10h (9%)

### Par phase :

1. **Setup** : 4h
2. **Modèles** : 10h (CRITIQUE - base du système)
3. **Menus** : 12h
4. **Listes courses** : 10h (logique complexe conversions)
5. **Social** : 8h
6. **Policies** : 5h
7. **Controllers** : 15h
8. **Vues** : 18h
9. **Stimulus** : 10h
10. **Scopes** : 5h
11. **Seeds** : 8h (répartis)
12. **Tests** : 25h (parallèle)
13. **Polish** : 8h
14. **Deploy** : 5h

---

# 🎯 ORDRE DE CRÉATION - CHECKLIST DÉTAILLÉE

## ✅ Checkpoint 1 : FONDATIONS (Jours 1-2)

- [ ] Phase 0 complète
- [ ] User étendu (admin, preferences)
- [ ] Ingredient complet avec tests
- [ ] Tag avec tests
- [ ] Seeds ingredients (critiques)

**Livrable** : Base données avec ingrédients, admin créé

## ✅ Checkpoint 2 : RECETTES (Jours 3-4)

- [ ] Recipe avec ActiveStorage
- [ ] RecipeTag
- [ ] Preparation avec conversions
- [ ] Seeds tags
- [ ] Seeds recipes (avec preparations)
- [ ] RecipesController#index basique

**Livrable** : Catalogue recettes consultable

## ✅ Checkpoint 3 : GÉNÉRATION MENUS (Jours 5-7)

- [ ] Menu & MenuRecipe
- [ ] MenuDraft (PORO)
- [ ] Menus::Generate service
- [ ] Menus::DraftActions service
- [ ] MenusController (new, preview, create)
- [ ] Vues génération + preview
- [ ] Stimulus meal_people

**Livrable** : UC1 fonctionnel (génération + personnalisation draft)

## ✅ Checkpoint 4 : PERSONNALISATION MENUS (Jours 8-9)

- [ ] Actions MenusController (show, update, save_and_regenerate)
- [ ] Menus::DraftController complet
- [ ] Vues menu persisté
- [ ] Policies Menu/MenuRecipe
- [ ] Tests UC2

**Livrable** : UC2 fonctionnel (édition menus persistés)

## ✅ Checkpoint 5 : LISTES DE COURSES (Jours 10-12)

- [ ] GroceryItem modèle
- [ ] GroceryLists::Generate service
- [ ] GroceryLists::Regenerate service
- [ ] GroceryListsController
- [ ] Vues liste + modal ajout
- [ ] Stimulus grocery_item + modal
- [ ] Policies GroceryItem/Ingredient
- [ ] Tests UC3

**Livrable** : UC3 fonctionnel (listes complètes)

## ✅ Checkpoint 6 : FICHE RECETTE (Jours 13-14)

- [ ] FavoriteRecipe modèle
- [ ] Review modèle
- [ ] Recipes::ScaleIngredients service
- [ ] RecipesController#show complet (contexte menu)
- [ ] FavoritesController
- [ ] ReviewsController
- [ ] Vue recipe show détaillée
- [ ] Stimulus favorite + rating
- [ ] Tests UC4

**Livrable** : UC4 fonctionnel (interactions recettes)

## ✅ Checkpoint 7 : RECHERCHE (Jours 15-16)

- [ ] Recipe scopes avancés
- [ ] Ransackers jsonb
- [ ] RecipesController#index complet (filtres)
- [ ] Vue index avec filtres
- [ ] Stimulus filters
- [ ] Tests UC5

**Livrable** : UC5 fonctionnel (catalogue avec recherche)

## ✅ Checkpoint 8 : POLISH (Jours 17-18)

- [ ] Toutes policies complètes
- [ ] Tests feature complets (6 UC)
- [ ] I18n
- [ ] Optimisations N+1
- [ ] Error pages
- [ ] CI setup
- [ ] Deploy staging

**Livrable** : Application production-ready

---

# 🌱 SEEDS - STRATÉGIE DÉTAILLÉE

## Ordre d'exécution :

1. **Ingredients** (100+) - 3h création
2. **Tags** (20-30) - 30min
3. **Recipes** avec Preparations (30-50) - 3h
4. **Users** (admin + démo) - 30min
5. **Menus démo** - 30min
6. **Reviews/Favoris** - 30min

## Structure fichiers :

```
db/
  seeds.rb (orchestrateur)
  seeds/
    ingredients.rb
    tags.rb
    recipes.rb
    users.rb
    demo_data.rb
```

## Données minimales viables :

- **20 ingrédients** (MVP test)
- **10 recettes** variées
- **10 tags** essentiels
- **1 admin + 2 users**

## Données complètes production :

- **150+ ingrédients** (tous rayons, saisons)
- **50+ recettes** (diets variés)
- **30 tags**

---

# ⚡ POINTS D'ATTENTION SPÉCIAUX

1. **Conversions unités spoons** : Complexe, bien tester arrondi 0.25 càc
2. **Non-duplication recettes** : Logique critique dans génération
3. **Session draft** : Taille limitée, sérialiser efficacement
4. **Régénération listes** : Bien distinguer generated vs manual
5. **Pundit partout** : Ne jamais oublier `authorize`
6. **Photos Cloudinary** : Variants définis tôt
7. **Tests saisonnalité** : Mocker `Date.current.month` dans specs

---

# 🚀 RECOMMANDATIONS FINALES

1. **Commencer par Phase 0-1** : Fondations solides = gain de temps
2. **Tester au fur et à mesure** : Pas de phase test séparée
3. **Seeds tôt** : Ingrédients dès Phase 1, recettes dès Phase 2
4. **UI minimale d'abord** : Polish après fonctionnel
5. **Pundit dès Phase 5** : Sécurité non négociable
6. **Feature flags** : Si déploiement incrémental souhaité

Bonne chance ! 🎉

LES TABLES

# users (UC6)

- email, encrypted_password (Devise)
- admin:boolean (default: false)
- default_diet:integer (enum)
- default_people:integer (default: 4)

# ingredients (UC3/UC5) ✅ DÉJÀ FAIT

- name:string (unique)
- category:integer (enum rayon)
- unit_group:integer (enum mass/volume/count/spoon)
- base_unit:string (g/ml/piece/cac)
- season_months:integer[] (array 1..12)
- aliases:jsonb

# recipes (UC1/UC4/UC5)

- name:string
- description:text
- instructions:text
- default_servings:integer (NOT NULL)
- prep_time_minutes:integer
- cook_time_minutes:integer
- difficulty:integer (enum)
- price:integer (enum)
- diet:integer (enum, NOT NULL)
- appliance:string
- source_url:string

# + photo via ActiveStorage

# preparations (UC1/UC3/UC4)

- recipe_id, ingredient_id
- quantity_base:decimal(10,3)

# tags (UC4/UC5)

- name:string (unique)
- tag_type:integer (enum optionnel)

# recipe_tags (UC4/UC5)

- recipe_id, tag_id (unique ensemble)

# menus (UC1/UC2)

- user_id
- diet:integer (enum)
- number_of_people:integer
- number_of_meals:integer

# menu_recipes (UC1/UC2)

- menu_id, recipe_id
- number_of_people:integer
- source:integer (enum generated/manual)

# grocery_items (UC3)

- menu_id, menu_recipe_id (optionnel), ingredient_id (optionnel)
- name:string
- quantity_base:decimal(10,3)
- unit_group:integer, base_unit:string
- quantity_display:decimal(10,3), unit_display:string
- category:integer (enum rayon)
- checked:boolean
- source:integer (enum generated/manual)

# favorite_recipes (UC4)

- user_id, recipe_id (unique)

# reviews (UC4)

- user_id, recipe_id (unique)
- rating:integer (1..5)
- content:text

# accesses (UC7 - partage, plus tard)

- user_id, menu_id

🔍 Analyse comparative de votre ancien schéma vs. besoins UC1-UC6
Votre ancien schéma a une bonne base, mais il manque beaucoup d'éléments critiques pour les nouveaux objectifs. Voici l'analyse détaillée :

✅ Ce qui est BIEN dans l'ancien schéma
Structure générale cohérente (users, recipes, ingredients, preparations, menus, menu_recipes)
Relations claires et logiques
favorite_recipes et reviews déjà en place
grocery_items pour la liste de courses
❌ Problèmes MAJEURS par rapport aux UC1-UC6
1️⃣ ingredients : TROP SIMPLE ⚠️
Ancien :

Nécessaire pour UC3/UC5 :

Impact : Sans ces champs, impossible de faire UC1 (saison), UC3 (conversions kg↔g), UC5 (recherche).

2️⃣ preparations : Quantités mal stockées
Ancien :

Nécessaire pour UC3/UC4 :

Impact : Impossible de recalculer/convertir (UC3, UC4).

3️⃣ recipes : Champs manquants/mal typés
Ancien :

Nécessaire pour UC1/UC4/UC5 :

Impact : Sans default_servings, impossible de recalculer les quantités (UC4, UC3). Sans temps/difficulté en integer, filtres UC5 cassés.

4️⃣ filters/filters_recipes : Système rigide ❌
Ancien :

Nécessaire pour UC4/UC5 :

Impact : Filtres UC5 limités, pas de navigation par tags UC4.

5️⃣ grocery_items : Manque champs UC3
Ancien :

Nécessaire pour UC3 :

Impact : Impossible de régénérer correctement (UC3 Option A).

6️⃣ menu_recipes : Champs inutiles
Ancien :

Nécessaire pour UC2 :

Impact : Champs done/favorite créent confusion.

7️⃣ users : Manque préférences UC6
Ancien :

Nécessaire pour UC6 :

Impact : UC6 impossible, pas de pré-remplissage UC1.

8️⃣ menus : Diet en string
Ancien :

Nécessaire pour UC1/UC2 :

🎯 Schéma recommandé pour EasyMeal v2
Voici le schéma optimal intégrant toutes les améliorations :

🚀 Plan d'action recommandé
Vu que vous avez déjà ingredients (nouveau modèle ✅), je recommande :

Créer recipes + preparations (base UC1/UC4/UC5)
Créer tags + recipe_tags (UC4/UC5)
Mettre à jour users avec admin/default_diet/default_people (UC6)
Créer menus + menu_recipes (UC1/UC2)
Créer grocery_items amélioré (UC3)
Créer favorite_recipes + reviews (UC4)
