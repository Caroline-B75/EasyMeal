UC1 — Générer un menu
Version : 2.0 (architecture draft persisté en base)
Contexte : EasyMeal (Rails 7.2), Devise, Pundit, Haml, Turbo/Stimulus, RSpec.

---

## Décision architecturale clé

Un brouillon de menu EST un menu. La distinction draft/actif est portée par un champ `status` sur le modèle `Menu`, pas par une architecture parallèle en session.

**Pourquoi pas la session ?**

- Limite 4 Ko : dépassée dès ~10 recettes avec métadonnées
- Multi-onglets : état corrompu sans solution propre
- Perte de données : fermeture d'onglet = menu perdu
- Flux ajout manuel (/recipes → retour) : fragile et non testable
- Complexité artificielle : simuler ce qu'ActiveRecord fait nativement

---

## 0. Objectif métier

À partir de 3 paramètres — régime, nombre de personnes (défaut), nombre de repas — l'utilisateur génère un menu en statut `draft`, persisté immédiatement en base, priorisant les recettes de saison au mois courant (sans bloquer si insuffisant).
Dès la génération, il peut personnaliser : supprimer, remplacer aléatoirement, modifier le nombre de personnes par repas, ou ajouter un nouveau repas.
Quand il est satisfait, il "active" le menu (status → active), ce qui génère sa liste de courses.

---

## 1. Glossaire

- **Menu(status: :draft)** : brouillon persisté en base, modifiable à volonté, non encore "finalisé". Nettoyage automatique après 7 jours d'inactivité.
- **Menu(status: :active)** : menu confirmé, avec sa liste de courses associée. **Un seul menu actif par utilisateur à un instant donné.**
- **Menu(status: :archived)** : ancien menu actif, conservé dans l'historique. Consultable en lecture seule, réactivable.
- **MenuRecipe** : un repas du menu — recipe + number_of_people (override local) + meal_type optionnel.
- **Pool saison** : recettes compatibles avec le régime du menu ET ayant au moins un ingrédient de saison au mois courant.
- **Pool hors saison** : recettes compatibles avec le régime, non présentes dans le pool saison.
- **Hiérarchie des régimes** : vegan ⊂ végétarien ⊂ omnivore (et pescétarien ⊂ omnivore). Une recette vegan est compatible avec un menu végétarien.

---

## 2. Portée (in / out)

**Inclus (UC1)**

- Formulaire de génération : diet, default_people, number_of_meals.
- Création du Menu(status: :draft) + ses MenuRecipe en base.
- Personnalisation immédiate : supprimer / remplacer aléatoirement / modifier nb de personnes / ajouter un repas (aléatoire ou manuel).
- Activation du menu (draft → active) → déclenche la génération de la liste de courses (UC3).
- Unicité du menu actif : l'activation archive automatiquement le menu actif précédent.

**Exclus (hors UC1)**

- Liste de courses (UC3).
- Partage (V2).
- Réactivation d'un menu archivé (UC2).

---

## 3. Modèle de données

### Colonnes ajoutées à menus

`status        : integer, default: 0, null: false  # enum: draft=0, active=1, archived=2
diet          : integer                            # enum aligné avec Recipe.diet
default_people: integer, default: 2, null: false`

### Enum status sur Menu

`
uby
enum :status, { draft: 0, active: 1, archived: 2 }, prefix: true

scope :drafts, -> { where(status: :draft) }
scope :active_menus, -> { where(status: :active) }
scope :archived, -> { where(status: :archived) }
scope :stale_drafts, -> { draft.where("updated_at < ?", 7.days.ago) }
`

### Contrainte d'unicité du menu actif

Index partiel unique : `(user_id) WHERE status = 1` — garantit au plus UN menu actif par utilisateur au niveau DB.

### Unicité sur menu_recipes

Contrainte DB : index unique sur (menu_id, recipe_id) — empêche les doublons au niveau base de données (filet de sécurité, la logique applicative vérifie en amont).

---

## 4. Hiérarchie des régimes alimentaires

`
uby

# app/models/recipe.rb

DIET_COMPATIBILITY = {
"omnivore" => %w[omnivore vegetarien vegan pescetarien],
"pescetarien" => %w[vegetarien vegan pescetarien],
"vegetarien" => %w[vegetarien vegan],
"vegan" => %w[vegan]
}.freeze

scope :compatible_with, ->(diet) {
where(diet: DIET_COMPATIBILITY.fetch(diet.to_s, [diet.to_s]))
}
`

---

## 5. Entrées / sorties

**Entrées (formulaire initial)**

- `diet` (enum, défaut depuis `current_user.default_diet`)
- `default_people` (≥ 1, défaut depuis `current_user.default_people`)
- `number_of_meals` (≥ 1)

**Sorties**

- `Menu(status: :draft)` persisté avec `number_of_meals` MenuRecipes.
- Chaque MenuRecipe : recipe_id, number_of_people = menu.default_people.
- Redirection vers `GET /menus/:id` (page de personnalisation).

---

## 6. Règles métier

1. **Anti-doublon** : une recette ne peut apparaître qu'une fois dans un même menu (contrainte DB + vérification applicative).
2. **Priorité saison** : remplir d'abord depuis le pool saison (mois courant), puis compléter hors saison si insuffisant. Ne bloque jamais.
3. **Hiérarchie régimes** : utiliser `Recipe.compatible_with(diet)` qui inclut les régimes plus restrictifs.
4. **Nombre de personnes par repas** : initialisé à `menu.default_people`, modifiable indépendamment, conservé lors d'un remplacement.
5. **Ajouter aléatoire** : tire une recette compatible (pool saison → pool hors saison), non dupliquée, initialise à `menu.default_people`.
6. **Ajouter manuel** : l'utilisateur navigue vers `/recipes?for_menu=<id>`, clique "Ajouter au menu", crée un MenuRecipe via `POST /menu_recipes`.
7. **Épuisement des candidats** : flash Turbo Stream "Plus de recettes disponibles pour ce critère", aucun repas n'est ajouté.
8. **Activation** : `menu.activate!` passe le status à `:active`, déclenche `Groceries::BuildForMenuService`.
9. **Unicité du menu actif** : un seul menu actif par utilisateur. L'activation archive automatiquement le menu actif précédent (`status → :archived`).
10. **Archivage automatique** : quand un menu est activé, les menus précédemment actifs du même utilisateur passent en `:archived`.

---

## 7. Services

### Menus::GenerateService

`Menus::GenerateService.call(user:, diet:, default_people:, number_of_meals:)
→ Menu (status: :draft, persisted)`

Algorithme :

1. Construire pool_seasonal = Recipe.compatible_with(diet).seasonal_for_month(month).shuffle
2. Construire pool_other = Recipe.compatible_with(diet).where.not(id: pool_seasonal).shuffle
3. Piocher number_of_meals recettes : saison d'abord, hors saison en complément
4. Créer Menu + MenuRecipe dans une transaction

### Menus::AddRandomMealService

`Menus::AddRandomMealService.call(menu:)
→ MenuRecipe | raises Menus::NoCandidatesError`

### Menus::ReplaceMealService

`Menus::ReplaceMealService.call(menu:, menu_recipe:)
→ MenuRecipe | raises Menus::NoCandidatesError`
Conserve menu_recipe.number_of_people.

---

## 8. Routing & contrôleurs

`
uby

# config/routes.rb

resources :menus do
member do
post :activate # draft → active + génère grocery list
post :add_random_meal # ajoute un repas aléatoire
end
end

resources :menu_recipes, only: [:create, :destroy, :update]

# :create → ajout manuel depuis /recipes

# :destroy → suppression d'un repas

# :update → modification du nb de personnes

resources :recipes do
member { post :add_to_menu } # POST /recipes/:id/add_to_menu
end
`

**MenusController** : new, create (génère le draft), show (page de personnalisation + menu actif), activate, add_random_meal
**MenuRecipesController** : create, destroy, update — toutes les réponses en Turbo Stream

---

## 9. UX

**Page /menus/new**

- Formulaire : régime (select pré-rempli depuis current_user.default_diet), personnes (stepper +/−), nb de repas (stepper +/−)
- Bouton "Générer mon menu" (CTA principal anthracite)

**Page /menus/:id** (même page pour draft et menu actif, différenciée par @menu.status)

- Header : nom, badge statut (Brouillon / Actif), diet, nb repas, nb pers par défaut
- Bouton "Ajouter un repas" → dropdown : "Aléatoirement" | "Choisir dans la base"
- Turbo Frame id="menu_meals" → liste de \_meal_card
- Si draft? : CTA "Enregistrer ce menu" → POST /menus/:id/activate
- Si active? : lien "Voir la liste de courses"

**Carte repas (\_meal_card)**

- Vignette photo | Titre | Badge "de saison" (fond ambre --color-accent)
- Stepper − [N pers] + (Turbo Stream via form)
- Icône Remplacer | Icône Supprimer

**Sur /recipes** si draft actif :

- Bandeau "Vous composez un menu – [Revenir]"
- Bouton "Ajouter au menu" sur chaque carte recette (visible uniquement si param for_menu présent)

---

## 10. TDD — Scénarios d'acceptation (Gherkin)

`gherkin
Feature: Générer un menu

Background:
Given un utilisateur connecté (diet: vegetarien, default_people: 4)
And le mois courant est août
And la base contient des recettes vegetariennes et vegan de saison et hors saison

Scenario: Génération initiale — priorité saison et hiérarchie régimes
When je soumets le formulaire (diet: vegetarien, personnes: 4, repas: 6)
Then un Menu(status: draft) est créé en base avec 6 MenuRecipes
And les recettes vegan sont incluses dans le pool "végétarien"
And les recettes de saison sont priorisées
And aucun doublon n'existe

Scenario: Ajouter un repas aléatoire
Given un menu draft de 6 repas
When je clique "Ajouter un repas" puis "Aléatoirement"
Then un 7ème MenuRecipe est créé en base
And sa recette n'est pas déjà présente dans le menu
And son number_of_people = 4 (défaut du menu)
And la carte apparaît sans rechargement de page (Turbo Stream)

Scenario: Ajouter un repas manuel
Given un menu draft de 6 repas
When je clique "Ajouter un repas" puis "Choisir dans la base"
And j'arrive sur /recipes?for_menu=<id> avec le bandeau "Vous composez un menu"
And je clique "Ajouter au menu" sur "Salade grecque"
Then je suis redirigé vers /menus/:id
And "Salade grecque" apparaît dans la liste avec 4 pers

Scenario: Épuisement des candidats
Given toutes les recettes compatibles sont déjà dans le menu
When je clique "Ajouter un repas" puis "Aléatoirement"
Then je vois "Plus de recettes disponibles pour ce critère"
And aucun MenuRecipe n'est créé

Scenario: Activation du menu
Given un menu draft de 6 repas personnalisés
When je clique "Enregistrer ce menu"
Then le menu passe en status :active
And la liste de courses est générée
And je suis redirigé vers la liste de courses

Scenario: Activation archive le menu actif précédent
Given un menu actif existant "Menu semaine 1"
And un nouveau menu draft de 6 repas
When je clique "Enregistrer ce menu"
Then le nouveau menu passe en status :active
And "Menu semaine 1" passe en status :archived
And un seul menu est actif pour cet utilisateur
`

---

## 11. Specs de services (RSpec)

`
uby
RSpec.describe Menus::GenerateService do
let(:user) { create(:user) }

it "crée un Menu draft persisté avec le bon nombre de repas" do
create_list(:recipe, 10, :vegetarienne, :with_any_ingredient)
menu = described_class.call(user: user, diet: :vegetarien, default_people: 4, number_of_meals: 6)

    expect(menu).to be_persisted
    expect(menu).to be_status_draft
    expect(menu.menu_recipes.count).to eq(6)
    expect(menu.default_people).to eq(4)

end

it "priorise les recettes de saison" do
seasonal = create_list(:recipe, 4, :vegetarienne, :seasonal_for_current_month)
\_offseason = create_list(:recipe, 6, :vegetarienne, :non_seasonal)

    menu = described_class.call(user: user, diet: :vegetarien, default_people: 4, number_of_meals: 4)

    included_ids = menu.menu_recipes.pluck(:recipe_id)
    expect(included_ids & seasonal.map(&:id)).to eq(included_ids)

end

it "inclut les recettes vegan dans un menu végétarien (hiérarchie régimes)" do
create_list(:recipe, 5, :vegan, :with_any_ingredient)
menu = described_class.call(user: user, diet: :vegetarien, default_people: 4, number_of_meals: 3)

    diets = Recipe.where(id: menu.menu_recipes.pluck(:recipe_id)).pluck(:diet)
    expect(diets).to all(be_in(%w[vegetarien vegan]))

end

it "ne génère aucun doublon" do
create_list(:recipe, 10, :vegetarienne, :with_any_ingredient)
menu = described_class.call(user: user, diet: :vegetarien, default_people: 4, number_of_meals: 8)

    ids = menu.menu_recipes.pluck(:recipe_id)
    expect(ids.uniq.size).to eq(ids.size)

end
end

RSpec.describe Menus::AddRandomMealService do
let(:menu) { create(:menu, :draft, diet: :vegetarien, default_people: 4) }

it "ajoute un MenuRecipe non dupliqué priorisant la saison" do
create_list(:recipe, 3, :vegetarienne, :seasonal_for_current_month)
expect { described_class.call(menu: menu) }
.to change { menu.menu_recipes.count }.by(1)
expect(menu.menu_recipes.order(:created_at).last.number_of_people).to eq(4)
end

it "lève Menus::NoCandidatesError si tout est épuisé" do
existing = create(:recipe, :vegetarienne, :with_any_ingredient)
create(:menu_recipe, menu: menu, recipe: existing)
expect { described_class.call(menu: menu) }
.to raise_error(Menus::NoCandidatesError)
end
end
`

---

## 12. Checklist PO/QA

- [ ] Menu draft créé en base avec le bon nombre de repas
- [ ] Hiérarchie régimes respectée (vegan inclus dans végétarien, etc.)
- [ ] Recettes de saison priorisées, jamais bloquant si insuffisant
- [ ] Aucun doublon dans la génération initiale
- [ ] Personnalisation immédiate accessible dès la génération
- [ ] Ajout aléatoire : anti-doublon, initialise à default_people
- [ ] Ajout manuel : flux /recipes → retour menu → nouveau repas visible
- [ ] Message clair si pool épuisé
- [ ] Nombre de personnes modifiable par repas
- [ ] Activation → liste de courses générée → redirection
- [ ] Activation archive automatiquement le menu actif précédent
- [ ] Un seul menu actif par utilisateur (contrainte DB + logique applicative)
- [ ] Nettoyage des drafts > 7 jours (CleanupStaleDraftsJob)
