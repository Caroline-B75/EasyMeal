UC3 — Liste de courses
Version : 2.0 (modèle GroceryItem documenté, cohérent avec architecture UC1/UC2 v2)
Contexte : EasyMeal (Rails 7.2), Devise, Pundit, Haml, Turbo/Stimulus, RSpec.
Prérequis : un Menu(status: :active) contenant des MenuRecipes (chaque repas a son number_of_people).

---

## 0. Objectif métier

À partir d'un menu activé, générer et afficher une liste de courses consolidée :
- Agrégation de tous les ingrédients de chaque recette du menu.
- Prise en compte du number_of_people par repas (override local).
- Conversion interne vers l'unité de base de l'ingrédient, puis humanisation à l'affichage (3000 g → 3 kg).
- Affichage par rayon (catégorie d'ingrédient), chaque ligne affichant :
  case à cocher (acheté), nom, quantité humanisée, icône éditer, icône supprimer.
- Ajout manuel d'une ligne (ingrédient existant, ligne custom, ou création ingrédient admin).
- Régénération déclenchée depuis UC2 ("Mettre à jour la liste") : écrase les items :generated, conserve les :manual.

---

## 1. Modèle GroceryItem

### Colonnes (table grocery_items)

`
id             : bigint, PK
menu_id        : bigint, FK menus, null: false
ingredient_id  : bigint, FK ingredients, null: true   # null pour les items custom
name           : string, null: false                   # affiché + fallback si custom
quantity_base  : decimal(10,3), null: false            # toujours en unité de base
unit_group     : integer, null: false                  # enum: mass/volume/count/spoon
base_unit      : string, null: false                   # g, ml, piece, cac
checked        : boolean, default: false, null: false
source         : integer, default: 0, null: false      # enum: generated=0, manual=1
position       : integer                               # ordre d'affichage au sein du rayon
created_at     : datetime
updated_at     : datetime
`

### Index

`
index on (menu_id)                  → récupération rapide de tous les items d'un menu
index on (menu_id, source)          → filtrage generated/manual pour la régénération
index on (menu_id, ingredient_id)   → agrégation et recherche de doublons
`

### Enums

`uby
enum :source, { generated: 0, manual: 1 }, prefix: true
enum :unit_group, { mass: 0, volume: 1, count: 2, spoon: 3 }, prefix: true
`

### Associations & validations

`uby
class GroceryItem < ApplicationRecord
  belongs_to :menu
  belongs_to :ingredient, optional: true  # null si item custom sans ingredient en base

  validates :name,          presence: true
  validates :quantity_base, numericality: { greater_than: 0 }
  validates :unit_group,    presence: true
  validates :base_unit,     presence: true

  scope :generated, -> { where(source: :generated) }
  scope :manual,    -> { where(source: :manual) }
  scope :checked,   -> { where(checked: true) }
  scope :by_category, ->(category) { joins(:ingredient).where(ingredients: { category: category }) }
end
`

---

## 2. Glossaire

- **Ingredient** : category (rayon enum), season_months, aliases, unit_group, base_unit.
- **Preparation** : ligne recette ↔ ingrédient (quantity_base en unité de base).
- **GroceryItem** : ligne de la liste de courses persistée. source: :generated (calculé) ou :manual (ajouté manuellement).
- **quantity_base** : toujours stockée en unité de base de l'ingrédient (g, ml, piece, cac).
- **quantity_display** : valeur humanisée calculée à l'affichage (jamais stockée).

---

## 3. Unités & conversions

### Groupes d'unités (unit_group sur Ingredient)

| unit_group | base_unit | Exemples de saisie |
|------------|-----------|-------------------|
| mass       | g         | g, kg → converti en g |
| volume     | ml        | ml, L → converti en ml |
| count      | piece     | pièce, unité |
| spoon      | cac       | càc, càs (×3), pincée (×0.25) |

### Humanisation (Quantities::HumanizeService — existant)

| unit_group | Règle | Exemple |
|------------|-------|---------|
| mass | >= 1000g → kg | 3000g → "3 kg", 1500g → "1,5 kg" |
| volume | >= 1000ml → L | 1500ml → "1,5 L" |
| spoon | /3 → càs, sinon mixé, <1 et /0.25 → pincées | 5càc → "1 càs 2 càc", 0.5càc → "2 pincées" |
| count | entier si possible | 3.0 → "3", 2.5 → "2,5" |

Règles décimales : max 2 décimales, aucun zéro inutile (1,00 → 1 ; 1,50 → 1,5).

---

## 4. Portée (in / out)

**Inclus**
- Génération automatique lors de menu.activate! (UC1).
- Affichage groupé par rayon (catégorie).
- Toggle checked (Turbo, sans reload).
- Édition inline de la quantité (stylet).
- Ajout manuel via modale : ingrédient existant, ligne custom, ou création ingrédient (admin seulement).
- Régénération déclenchée depuis UC2 (POST /menus/:id/regenerate_grocery).

**Exclus**
- Gestion des stocks, nutrition, conversions densité (g ↔ ml).
- Fusion intelligente des ajustements lors d'une régénération (v1 : écrasement des :generated).

---

## 5. Service Groceries::BuildForMenuService (existant, à compléter)

### Responsabilité

Calculer et persister les GroceryItem(source: :generated) pour un menu.

### Algorithme

`uby
def call
  ActiveRecord::Base.transaction do
    # 1. Supprimer les items générés existants (régénération idempotente)
    @menu.grocery_items.generated.destroy_all

    # 2. Agréger ingrédients × facteur de portions par MenuRecipe
    aggregated = aggregate_by_ingredient

    # 3. Créer les nouveaux GroceryItem :generated
    aggregated.each_value { |data| create_grocery_item(data) }
  end
end

def aggregate_by_ingredient
  aggregated = Hash.new { |h, k| h[k] = { ingredient: nil, quantity_base: 0.0 } }

  @menu.menu_recipes
       .includes(recipe: { preparations: :ingredient })
       .each do |menu_recipe|
    factor = menu_recipe.number_of_people.to_f / menu_recipe.recipe.default_servings
    menu_recipe.recipe.preparations.each do |prep|
      key = prep.ingredient_id
      aggregated[key][:ingredient]    = prep.ingredient
      aggregated[key][:quantity_base] += prep.quantity_base * factor
    end
  end

  aggregated
end
`

**Important** : les GroceryItem(source: :manual) ne sont JAMAIS touchés par ce service.

---

## 6. Règles métier

1. **Calcul des facteurs** : factor = menu_recipe.number_of_people / recipe.default_servings pour chaque repas.
2. **Agrégation en base** : grouper par ingredient_id, sommer les quantity_base * factor.
3. **Humanisation** : calculée à l'affichage avec Quantities::HumanizeService (pas stockée).
4. **Classement** : par rayon (ingredient.category), ordre fixe des rayons, puis alphabétique par nom au sein du rayon.
5. **Édition inline** : la quantité modifiée est convertie en base puis persistée sur GroceryItem.quantity_base.
6. **Toggle checked** : PATCH /grocery_items/:id {checked: true/false} → Turbo Stream replace de la ligne.
7. **Régénération** :
   1. Supprimer uniquement les GroceryItem(source: :generated) du menu
   2. Reconstruire ces lignes d'après les MenuRecipes courants
   3. Ne jamais toucher aux GroceryItem(source: :manual)
   Les items :generated recréés partent avec checked: false.
   Les items :manual conservent leur checked.

---

## 7. Ajout manuel — pop-up "Ajouter une course"

Trois chemins dans la même modale :

**A. Ingrédient existant**
- Autocomplete sur Ingredient (nom + aliases)
- Saisie quantité + unité compatible (g/kg, ml/L, càc/càs/pincée, pièce)
- Conversion → quantity_base → crée GroceryItem(source: :manual, ingredient_id: <id>, category: ingredient.category)

**B. Ligne custom (sans ingrédient en base)**
- "Introuvable ? Ajouter sans enregistrer"
- Formulaire : name, category (rayon), quantité, unit_group
- Crée GroceryItem(source: :manual, ingredient_id: nil, name: ..., category: ...)

**C. Créer un ingrédient (admin uniquement)**
- Visible seulement si current_user.admin?
- "Créer dans la base d'ingrédients" → formulaire complet (name, category, unit_group, base_unit, aliases, season_months)
- Crée Ingredient puis GroceryItem(source: :manual, ingredient_id: new_ingredient.id)
- Non-admin → redirigé vers chemin B

---

## 8. Sécurité & autorisations (Pundit)

- **GroceryItemPolicy** : lecture/écriture si grocery_item.menu.user == current_user.
- Création d'Ingredient (chemin C) : vérifie current_user.admin? (levée NotAuthorizedError sinon).

---

## 9. Routing & contrôleurs

`uby
resources :menus do
  member do
    post :regenerate_grocery  # UC2 → rebuild liste
  end
  resources :grocery_items, only: [:index, :create, :update, :destroy]
  # GET  /menus/:menu_id/grocery_items       → liste de courses
  # POST /menus/:menu_id/grocery_items       → ajout manuel
  # PATCH /menus/:menu_id/grocery_items/:id  → edit inline / toggle checked
  # DELETE /menus/:menu_id/grocery_items/:id → supprimer ligne
end
`

**GroceryItemsController** :
- index → liste groupée par rayon
- create → ajout manuel (chemin A/B/C), répond Turbo Stream
- update → toggle checked ou edit quantité, répond Turbo Stream
- destroy → supprime la ligne, répond Turbo Stream

---

## 10. UX

**Page /menus/:id/grocery_items** (ou /menus/:id/liste-de-courses)
- Sections par rayon (ordre fixe des catégories Ingredient)
- Chaque ligne : [ ] nom — quantité humanisée — ✎ — 🗑
- Barre d'actions : bouton "Ajouter une course" (ouvre la modale)
- Bandeau en haut si menu modifié depuis dernière génération

**Édition inline (✎)**
- Champ quantité + sélecteur d'unité compatible (g/kg selon unit_group)
- Conversion → base à l'enregistrement
- Turbo Stream replace de la ligne

**Toggle checked**
- Click sur la case → PATCH immédiat → Turbo Stream (ligne barrée/non barrée)
- Optimistic UI via Stimulus (feedback visuel instantané avant réponse serveur)

---

## 11. TDD — Scénarios d'acceptation (Gherkin)

`gherkin
Feature: Liste de courses

  Background:
    Given un menu actif avec plusieurs repas
    And chaque repas a son number_of_people
    And les recettes ont des preparations en unités de base

  Scenario: Génération lors de l'activation du menu
    When le menu passe en status :active
    Then Groceries::BuildForMenuService est appelé automatiquement
    And des GroceryItem(source: :generated) sont créés
    And ils sont groupés par rayon à l'affichage

  Scenario: Agrégation et humanisation
    Given deux repas totalisent 3000 g de "Pâtes"
    Then la ligne "Pâtes" affiche "3 kg"

  Scenario: Spoons (càs, càc, pincées)
    Given trois recettes demandent "Paprika" totalisant 5 càc
    Then la ligne "Paprika" affiche "1 càs 2 càc"

  Scenario: Édition inline
    Given "Lait" affiche "1,5 L"
    When je clique ✎ et saisis "500 ml"
    Then GroceryItem.quantity_base = 500, la ligne affiche "500 ml"

  Scenario: Toggle checked
    When je coche "Pâtes — 3 kg"
    Then checked: true en base, ligne barrée (Turbo Stream)

  Scenario: Ajout manuel ingrédient existant
    When j'ouvre la modale et cherche "Tomates", saisis "500 g"
    Then un GroceryItem(source: :manual) est créé dans "fruits_legumes"
    And la ligne "Tomates — 500 g" apparaît sans reload

  Scenario: Ajout ligne custom (sans ingrédient base)
    When j'ouvre la modale, choisis "Ajouter sans enregistrer"
    And je saisis name: "Levure chimique", rayon: epicerie_sucree, 2 pièces
    Then un GroceryItem(source: :manual, ingredient_id: nil) est créé

  Scenario: Régénération depuis UC2
    Given un menu actif avec des items :generated et :manual
    When UC2 déclenche regenerate_grocery
    Then seuls les items :generated sont recalculés
    And les items :manual sont intacts (checked conservé)
`

---

## 12. Specs de services (RSpec)

`uby
RSpec.describe Groceries::BuildForMenuService do
  let(:menu) { create(:menu, :active) }

  it "agrège correctement les quantités en base et humanise" do
    # Prépare recettes avec ingrédients connus
    # Vérifie les GroceryItem créés
    described_class.call(menu: menu)

    pates_item = menu.grocery_items.generated.joins(:ingredient)
                     .find_by(ingredients: { name: "Pâtes" })
    expect(pates_item.quantity_base).to eq(3000)
    expect(Quantities::HumanizeService.call(
      quantity: pates_item.quantity_base, unit_group: pates_item.unit_group
    )[:display]).to eq("3 kg")
  end

  it "ne touche pas aux items :manual lors d'une régénération" do
    manual = create(:grocery_item, :manual, menu: menu, name: "Vin blanc", quantity_base: 750)
    described_class.call(menu: menu)  # régénération

    expect(GroceryItem.find(manual.id)).to be_present
    expect(GroceryItem.find(manual.id).quantity_base).to eq(750)
  end

  it "repart avec checked: false pour les items :generated recréés" do
    described_class.call(menu: menu)
    expect(menu.grocery_items.generated.pluck(:checked)).to all(be false)
  end
end
`

---

## 13. Checklist PO/QA

- [ ] Liste générée automatiquement lors de l'activation du menu
- [ ] Affichage groupé par rayon, ordre fixe
- [ ] Humanisation correcte (g→kg, ml→L, càc→càs/pincées)
- [ ] Aucun zéro inutile dans les quantités
- [ ] Toggle checked persiste et reflété immédiatement (Turbo)
- [ ] Édition inline : conversion en base correcte, mise à jour persistée
- [ ] Ajout manuel : chemin A (ingrédient existant), B (custom), C (admin : création)
- [ ] Régénération : :generated recalculés, :manual intacts
- [ ] Items :manual conservent leur checked lors de la régénération
- [ ] Policy : seul le propriétaire du menu accède à sa liste
