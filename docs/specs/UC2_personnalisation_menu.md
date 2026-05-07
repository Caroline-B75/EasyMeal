UC2 — Personnaliser un menu
Version : 3.0 (architecture unifiée — draft, actif et archivé = même modèle Menu)
Contexte : EasyMeal (Rails 7.2), Devise, Pundit, Haml, Turbo/Stimulus, RSpec.
Prérequis : UC1 a créé un Menu(status: :draft) persisté en base.

---

## Décision architecturale clé

UC1 et UC2 ne sont plus deux contextes séparés (draft en session vs menu persisté).
Il s'agit du MÊME modèle `Menu`, avec un champ `status` (:draft, :active ou :archived).
Toutes les actions de personnalisation opèrent sur des `MenuRecipe` en base de données.
Pas de DraftController séparé. Pas de DraftActions PORO. Pas de session.

---

## 0. Objectif métier

Permettre à l'utilisateur de façonner son menu via 4 actions disponibles tant que le menu existe (draft ou actif) :

1. Supprimer un repas
2. Remplacer un repas aléatoirement (priorité saison, anti-doublon)
3. Modifier le nombre de personnes d'un repas (override local)
4. Ajouter un repas — aléatoire ou manuel

Pour un menu **actif**, toute modification déclenche une régénération de la liste de courses (après confirmation via modal).

Permettre également de **réactiver un menu archivé** depuis l'historique, ce qui en fait le nouveau menu actif (l'ancien actif est automatiquement archivé).

---

## 1. Glossaire

- **Menu(status: :draft)** : menu en cours de composition, pas encore de liste de courses.
- **Menu(status: :active)** : menu finalisé avec liste de courses générée. **Un seul par utilisateur à un instant donné.**
- **Menu(status: :archived)** : ancien menu actif, conservé dans l'historique. Consultable en lecture seule, réactivable.
- **MenuRecipe** : un repas — recipe + number_of_people + meal_type optionnel.
- **Pool saison** : Recipe.compatible_with(menu.diet).seasonal_for_month(mois courant).
- **Pool hors saison** : Recipe.compatible_with(menu.diet) excluant le pool saison.
- **present_recipe_ids** : les recipe_id déjà dans le menu (requis pour anti-doublon).

---

## 2. Portée (in / out)

**Inclus**

- Les 4 actions sur un menu quel que soit son statut (draft ou active).
- Anti-duplication des recettes dans un même menu.
- Priorité saison pour ajout/remplacement aléatoire (jamais bloquant).
- Conservation du number_of_people lors d'un remplacement.
- Sur menu actif : modal de confirmation avant d'enregistrer → régénération grocery list.
- Réactivation d'un menu archivé (popup de confirmation, l'ancien actif est archivé).
- Page /menus : 3 sections (brouillon, menu actif, historique).

**Exclus**

- Génération initiale (UC1).
- Liste de courses (UC3).
- Partage de menus (V2).

---

## 3. Acteurs & sécurité

- **Acteur** : utilisateur connecté, propriétaire du menu.
- **MenuPolicy** : toutes les actions vérifient `record.user == current_user`.
- **MenuRecipePolicy** : délègue à MenuPolicy du menu parent.

---

## 4. Entrées / sorties

| Action                    | Route                           | Entrée           | Sortie Turbo Stream                        |
| ------------------------- | ------------------------------- | ---------------- | ------------------------------------------ |
| Supprimer repas           | DELETE /menu_recipes/:id        | menu_recipe_id   | Retire la meal_card du DOM                 |
| Remplacer aléatoire       | POST /menus/:id/replace_meal    | menu_recipe_id   | Remplace la meal_card                      |
| Modifier nb personnes     | PATCH /menu_recipes/:id         | number_of_people | Met à jour meal_card                       |
| Ajouter aléatoire         | POST /menus/:id/add_random_meal | —                | Ajoute une meal_card                       |
| Ajouter manuel            | POST /menu_recipes              | recipe_id        | Ajoute une meal_card                       |
| Réactiver un menu archivé | POST /menus/:id/reactivate      | —                | Redirect vers le menu (popup confirmation) |

Toutes les réponses sont des **Turbo Streams** (pas de full-page reload).

---

## 5. Règles métier

1. **Anti-doublon** : vérifier `menu.menu_recipes.pluck(:recipe_id)` avant tout ajout/remplacement. Filet de sécurité : index unique DB sur (menu_id, recipe_id).
2. **Priorité saison** pour ajout/remplacement aléatoire :
   - Chercher d'abord dans pool saison \ present_recipe_ids
   - Puis pool hors saison \ present_recipe_ids
   - Si les deux vides → flash "Plus de recettes disponibles", aucune modification
3. **Hiérarchie régimes** : utiliser `Recipe.compatible_with(menu.diet)` (vegan ⊂ végétarien ⊂ omnivore).
4. **Remplacement** : conserve le `number_of_people` du MenuRecipe remplacé.
5. **Ajout** : initialise `number_of_people` à `menu.default_people`.
6. **Modification nb personnes** : valeur ≥ 1. Mise à jour immédiate en base.
7. **Menu actif — enregistrer modifications** :
   - Clic "Enregistrer mes modifications" → modal de confirmation
   - OK → `Groceries::BuildForMenuService.call(menu:)` (écrase les items :generated, conserve les :manual) → redirect vers liste de courses
   - Annuler → reste sur la page, modifications en cours non perdues (elles sont déjà en DB)

8. **Réactivation d'un menu archivé** :
   - Clic "Rendre actif" sur un menu archivé → popup de confirmation
   - OK → `menu.reactivate!` : l'ancien menu actif passe en `:archived`, le menu réactivé passe en `:active`, sa liste de courses est régénérée
   - Annuler → aucune modification
9. **Menu archivé en lecture seule** : un menu archivé affiche ses recettes mais ne permet pas les 4 actions de personnalisation. Seules les actions "Réactiver" et "Supprimer" sont disponibles.

---

## 6. Services

### Menus::AddRandomMealService

`
uby

# Réutilisé par UC1 (génération) et UC2 (ajout unitaire)

Menus::AddRandomMealService.call(menu:)

# → MenuRecipe (persisted)

# → raises Menus::NoCandidatesError si pool épuisé

`

### Menus::ReplaceMealService

`
uby
Menus::ReplaceMealService.call(menu:, menu_recipe:)

# → nouveau MenuRecipe (persisted)

# → raises Menus::NoCandidatesError si pool épuisé

# Conserve menu_recipe.number_of_people

# Supprime l'ancien menu_recipe

`

Les deux services utilisent la même logique de tirage :

`
uby

# Logique partagée dans Menus::CandidatePickerService (private)

def pick_candidate(menu:, excluded_ids: [])
present_ids = menu.menu_recipes.pluck(:recipe_id) + excluded_ids
month = Date.current.month

candidate = Recipe.compatible_with(menu.diet)
.seasonal_for_month(month)
.where.not(id: present_ids)
.sample

candidate ||= Recipe.compatible_with(menu.diet)
.where.not(id: present_ids + seasonal_ids(menu, month))
.sample

candidate || raise(Menus::NoCandidatesError)
end
`

---

## 7. Routing & contrôleurs

`
uby
resources :menus do
member do
post :activate # draft → active (UC1) post :reactivate # archived → active (réactivation) post :add_random_meal # ajoute un repas aléatoire
post :replace_meal # remplace un repas (params: menu_recipe_id)
post :regenerate_grocery # régénère la liste (déclenché depuis UC2 sur menu actif)
end
end

resources :menu_recipes, only: [:create, :destroy, :update]
`

**MenusController** : add_random_meal, replace_meal, regenerate_grocery, reactivate
**MenuRecipesController** : create (ajout manuel), destroy (supprimer), update (nb personnes)

---

## 8. UX

**Carte repas (\_meal_card)**

- Photo vignette | Titre | Badge "de saison" (ambre, --color-accent)
- Stepper − [N pers] + → PATCH /menu_recipes/:id via form hidden (Turbo)
- Bouton Remplacer (icône) → POST /menus/:id/replace_meal
- Bouton Supprimer (icône) → DELETE /menu_recipes/:id

**Bouton "Ajouter un repas"**

- Dropdown Stimulus : "Aléatoirement" → POST /menus/:id/add_random_meal
- "Choisir dans la base" → GET /recipes?for_menu=<id>

**Bandeau modifications (menu actif uniquement)**

- Apparaît dès qu'une action est effectuée sur un menu actif
- "Les modifications seront reflétées dans la liste de courses"
- Bouton "Mettre à jour la liste de courses" → POST /menus/:id/regenerate_grocery avec modal de confirmation

**Messages flash Turbo Stream**

- "Plus de recettes disponibles pour ce critère" (NoCandidatesError)
- "Cette recette est déjà dans votre menu" (doublon tentative manuelle)

**Page /menus (index) — 3 sections**

- Section "Brouillon en cours" : le draft actuel (s'il existe)
- Section "Menu actif" : le menu actif unique (s'il existe), avec lien vers le menu et la liste de courses
- Section "Historique" : les menus archivés, chacun avec les boutons "Voir", "Rendre actif" (popup de confirmation) et "Supprimer"

**Page /menus/:id (show) — menu archivé**

- Recettes affichées en lecture seule (pas de stepper, pas de remplacer/supprimer)
- Bannière "Ce menu est archivé" + bouton "Rendre ce menu actif" (popup de confirmation)

---

## 9. TDD — Scénarios d'acceptation (Gherkin)

`gherkin
Feature: Personnaliser un menu

Background:
Given un utilisateur connecté
And un menu draft (diet: vegetarien, default_people: 4, 6 repas)
And le mois courant est août
And des recettes vegetariennes et vegan disponibles (saison et hors saison)

Scenario: Supprimer un repas
When je supprime le repas #3
Then le MenuRecipe est supprimé en base
And la carte disparaît sans rechargement (Turbo Stream)
And le menu contient 5 repas

Scenario: Remplacer aléatoirement (priorité saison, conservation nb personnes)
Given le repas #2 a 2 personnes
When je remplace le repas #2
Then un nouveau MenuRecipe remplace l'ancien en base
And la nouvelle recette est végétarienne ou vegan, non dupliquée
And si des recettes de saison sont disponibles, une de saison est choisie
And le nouveau repas affiche 2 personnes (conservé)

Scenario: Modifier le nombre de personnes
When je passe le repas #4 à 2 personnes
Then menu_recipes[4].number_of_people = 2 en base
And seul #4 est mis à jour (Turbo Stream replace meal_card)

Scenario: Ajouter un repas aléatoire
When je clique "Ajouter un repas" puis "Aléatoirement"
Then un nouveau MenuRecipe est créé en base
And la recette n'est pas déjà présente
And number_of_people = 4 (défaut du menu)

Scenario: Ajouter un repas manuel depuis /recipes
When je clique "Ajouter un repas" puis "Choisir dans la base"
And j'arrive sur /recipes?for_menu=<id>
And je clique "Ajouter au menu" sur "Salade grecque"
Then POST /menu_recipes {recipe_id: <salade_id>, menu_id: <id>}
And je suis redirigé vers /menus/:id avec "Salade grecque" en bas de liste

Scenario: Pool épuisé
Given toutes les recettes compatibles sont dans le menu
When je tente d'ajouter ou remplacer aléatoirement
Then je vois "Plus de recettes disponibles pour ce critère"
And le menu n'est pas modifié

Scenario: Doublon manuel refusé
Given "Salade grecque" est déjà dans le menu
When je tente de l'ajouter manuellement
Then je vois "Cette recette est déjà dans votre menu"
And aucun MenuRecipe n'est créé

Scenario: Régénération liste sur menu actif
Given un menu actif avec une liste de courses générée
When je remplace un repas
And je clique "Mettre à jour la liste de courses" et confirme
Then Groceries::BuildForMenuService est appelé
And les items :generated sont recalculés (items :manual conservés)
And je suis redirigé vers la liste de courses mise à jour

Scenario: Réactiver un menu archivé
Given un menu actif "Menu semaine 1"
And un menu archivé "Menu semaine 0" dans l'historique
When je clique "Rendre actif" sur "Menu semaine 0" et confirme
Then "Menu semaine 0" passe en status :active
And sa liste de courses est régénérée
And "Menu semaine 1" passe en status :archived
And un seul menu est actif pour cet utilisateur

Scenario: Menu archivé en lecture seule
Given un menu archivé avec 6 repas
When j'ouvre la page du menu
Then je vois les 6 recettes affichées
And je ne vois pas les boutons Remplacer / Supprimer / Ajouter
And je vois le bouton "Rendre ce menu actif"

Scenario: Page index — 3 sections
Given un brouillon, un menu actif et 2 menus archivés
When j'accède à /menus
Then je vois la section "Brouillon en cours" avec 1 menu
And la section "Menu actif" avec 1 menu
And la section "Historique" avec 2 menus
And chaque menu archivé a un bouton "Rendre actif"
`

---

## 10. Specs de services (RSpec)

`
uby
RSpec.describe Menus::ReplaceMealService do
let(:menu) { create(:menu, :draft, diet: :vegetarien, default_people: 4) }
let(:old_recipe) { create(:recipe, :vegetarienne, :with_any_ingredient) }
let!(:menu_recipe) { create(:menu_recipe, menu: menu, recipe: old_recipe, number_of_people: 2) }

it "remplace le menu_recipe et conserve le nb de personnes" do
create(:recipe, :vegetarienne, :with_any_ingredient)

    new_mr = described_class.call(menu: menu, menu_recipe: menu_recipe)

    expect(new_mr).to be_persisted
    expect(new_mr.number_of_people).to eq(2)
    expect(new_mr.recipe_id).not_to eq(old_recipe.id)
    expect(MenuRecipe.exists?(menu_recipe.id)).to be false

end

it "lève NoCandidatesError si aucun candidat disponible" do
expect { described_class.call(menu: menu, menu_recipe: menu_recipe) }
.to raise_error(Menus::NoCandidatesError)
end

it "inclut les recettes vegan pour un menu végétarien" do
create(:recipe, :vegan, :with_any_ingredient)
new_mr = described_class.call(menu: menu, menu_recipe: menu_recipe)
expect(%w[vegetarien vegan]).to include(new_mr.recipe.diet)
end
end

RSpec.describe MenuRecipesController, type: :request do
let(:user) { create(:user) }
let(:menu) { create(:menu, :draft, user: user, diet: :vegetarien, default_people: 4) }

before { sign_in user }

describe "PATCH /menu_recipes/:id" do
let!(:mr) { create(:menu_recipe, menu: menu, number_of_people: 4) }

    it "met à jour le nb de personnes et répond en Turbo Stream" do
      patch menu_recipe_path(mr),
            params: { menu_recipe: { number_of_people: 2 } },
            headers: { "Accept" => "text/vnd.turbo-stream.html" }

      expect(response).to have_http_status(:ok)
      expect(mr.reload.number_of_people).to eq(2)
    end

    it "refuse la mise à jour si < 1" do
      patch menu_recipe_path(mr), params: { menu_recipe: { number_of_people: 0 } }
      expect(mr.reload.number_of_people).to eq(4)
    end

end
end
`

---

## 11. Checklist PO/QA

- [ ] Supprimer un repas : MenuRecipe supprimé en base, carte retirée du DOM (Turbo)
- [ ] Remplacer : nouvelle recette non dupliquée, compatible diet, priorité saison, # personnes conservé
- [ ] Modifier nb personnes : min 1, mise à jour immédiate, seul le repas concerné change
- [ ] Ajouter aléatoire : anti-doublon, priorité saison, initialise à default_people
- [ ] Ajouter manuel : anti-doublon validé, redirect vers le menu
- [ ] Pool épuisé : message clair, aucune modification
- [ ] Menu actif : banner modifications + confirmation avant régénération
- [ ] Régénération : items :generated recalculés, items :manual conservés
- [ ] Réactivation menu archivé : popup de confirmation, ancien actif archivé, liste de courses régénérée
- [ ] Menu archivé : lecture seule (recettes visibles, pas d'actions de personnalisation)
- [ ] Page index : 3 sections (brouillon, actif, historique)
- [ ] Bouton "Rendre actif" présent sur chaque menu archivé (index + show)
- [ ] Un seul menu actif par utilisateur (contrainte DB)
