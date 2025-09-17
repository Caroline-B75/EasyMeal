UC3 — Liste de courses
Version : 1.0
Contexte : EasyMeal (Rails 7.2), Devise, Pundit, Haml, Turbo/Stimulus, Tailwind (option), RSpec.
Prérequis : un Menu (ou MenuDraft enregistré) contenant des MenuRecipes (chaque repas a son number_of_people local).

---

0. Objectif métier
   À partir d’un menu enregistré, générer et afficher une liste de courses consolidée :
   • Agrégation de tous les ingrédients de chaque recette du menu.
   • Prise en compte du nombre de personnes par repas (override local).
   • Conversion interne vers une unité de base par ingrédient, puis humanisation des quantités à l’affichage (ex. 3000 g → 3 kg, pas de zéros inutiles).
   • Affichage par rayon (catégorie d’ingrédient), avec pour chaque ligne :
   o case à cocher (déjà acheté),
   o nom d’ingrédient,
   o quantité totale pour tout le menu,
   o icône stylet pour éditer la quantité côté utilisateur.
   • Ajout manuel d’une ligne : pop-up “Ajouter une course” permettant :

1) de sélectionner un ingrédient existant, ou
2) de créer un nouvel ingrédient (dans la même pop-up) puis l’ajouter directement dans la liste, au bon rayon.
   • Régénération : la liste est recalculée automatiquement lorsque l’utilisateur enregistre un menu modifié (voir UC2). On écrase uniquement les lignes generated, les lignes manual sont conservées.

---

1. Glossaire (rappel)
   • Ingredient : a category (rayon enum), season_months (array 1..12), aliases, et surtout une unité de base rattachée à un groupe d’unités.
   • Preparation : ligne recette ↔ ingrédient (quantité en unité de base).
   • GroceryItem : ligne de la liste de courses, avec quantity, unit_display/unit_base, checked, category, menu_id (et éventuellement menu_recipe_id).
   • source (enum) : generated | manual

---

2. Unités & conversions (FR, simples et robustes)
   a) Groupes d’unités (enum unit_group)
   • mass → base = g (gramme)
   • volume → base = ml (millilitre)
   • count → base = piece (pièce)
   • spoon → base = cac (cuillère à café)
   o conversions simples :
    1 càs = 3 càc
    1 pincée = 0,25 càc (approximation simple, v1)
    Arrondi des cuillères à 0,25 càc (pincée) au plus proche.
   Principe : chaque Ingredient choisit un unit_group + sa base_unit (comme ci-dessus).
   Preparation en base : on enregistre toujours la quantité convertie en base (ex. 1 càs → 3 càc ; 1 L → 1000 ml).

b) Humanisation (affichage)
• mass : >= 1000 g → kg (ex. 3000 g → 3 kg)
• volume : >= 1000 ml → L (ex. 1500 ml → 1,5 L)
• spoon (càc) :
o si divisible par 3 → afficher en càs (ex. 6 càc → 2 càs)
o sinon afficher mixé : X càs Y càc (ex. 5 càc → 1 càs 2 càc)
o si < 1 càc et multiple de 0,25 → afficher en pincées (ex. 0,5 càc → 2 pincées)
• count (piece) : entier si possible, sinon décimal autorisé.
Règles d’affichage des décimales
• Max 2 décimales.
• Aucun zéro inutile (ex. 1,00 L → 1 L, 1,50 L → 1,5 L).

---

3. Portée (in / out)
   Inclus
   • Génération et affichage de la liste (groupée par rayon).
   • Édition inline des quantités (stylet) + case à cocher “acheté”.
   • Ajout d’une ligne via pop-up : sélection d’un ingrédient existant ou création d’un nouvel ingrédient (dans la pop-up) puis insertion dans la liste.
   • Réception d’une régénération déclenchée depuis UC2 (save du menu) ; pas de bouton “Régénérer” sur cette page.
   Exclus
   • Gestion des stocks, conversions denses (g ↔ ml), nutrition.
   • Fusion “intelligente” des ajustements utilisateur lors d’une régénération (v1 = écrasement).

---

4. Entrées / sorties
   Entrées (service de génération)
   • menu_id (obligatoire)
   Sorties
   • GroceryList : collection d’items (par category) :
   o ingredient_id ou is_custom
   o name (affiché)
   o quantity_base (nombre en base), unit_group, base_unit
   o quantity_display + unit_display (humanisés pour l’UI)
   o checked (bool)
   o menu_recipe_id (option traçabilité)
   o category (rayon enum)

---

5. Règles métier (génération)

1) Calcul des facteurs de portions
   o Pour chaque MenuRecipe (repas) :
    factor = menu_recipe.number_of_people / recipe.default_servings
    Appliquer factor à chaque Preparation de la recette.
2) Agrégation en unité de base
   o Grouper par (ingredient_id, base_unit) (ou par name si custom sans ingredient_id).
   o sum(quantity_base \* factor) sur l’ensemble des repas du menu.
3) Humanisation pour l’UI
   o Appliquer les règles d’affichage ci-dessus par unit_group.
4) Classement par rayon
   o Utiliser ingredient.category (enum fermé).
   o Sections d’écran = rayons (ordre fixe recommandé).
5) Édition et case à cocher
   o checked changeable sans recharger (Turbo).
   o Stylet ouvre une mini-édition inline (ou pop-in légère) pour modifier quantity_display → convertie en quantity_base cohérente (attention aux unités spoon).
   o Les modifications utilisateur sont persistées (sur GroceryItem).
6) Régénération (déclenchée depuis UC2)
   • Déclencheur : clic “Enregistrer mes modifications” sur un menu persisté (cf. UC2).
   • Algorithme :

1. Supprimer uniquement les GroceryItems source = :generated du menu,
2. Reconstruire ces lignes à partir des recettes et des nombres de personnes,
3. Ne jamais toucher aux GroceryItems source = :manual.
   • Conséquences :
    Les ajouts manuels restent tels quels,
    Les edits de quantité faits sur des lignes générées sont perdus (réinitialisés d’après le menu)
    Les lignes generated recréées repartent avec checked = false.
    Les lignes manual conservent leur checked.

• UX : la page Liste de courses est affichée après recalcul (redirect depuis UC2).
******************\_\_\_\_****************** 6) Ajout d’un élément (“Ajouter une course”)
Pop-up avec 3 chemins :

A. Ajouter un ingrédient existant
• Auto-complétion sur ingredients (nom + aliases).
• Saisie quantité + unité compatible avec unit_group :
mass → g, kg (converti → g) ; volume → ml, L ;
spoon → càc, càs, pincée (converti → càc) ; count → pièce.
• Action : crée un GroceryItem source: :manual, lié à ingredient_id, quantity_base en base, category depuis l’ingrédient.

B. Ajouter “sans l’enregistrer en base” (switch OFF — défaut)
• Bouton : “Ingrédient introuvable ? Ajouter sans l’enregistrer”.
• Formulaire léger : name, category (rayon), quantity + unité, unit_group.
• Action : crée un GroceryItem source: :manual **sans ingredient_id** (ligne custom), stocké avec name, unit_group/base_unit, quantity_base, category.

C. Créer un nouvel ingrédient (switch ON) uniquement visible pour un admin
-> Réservé admin : si l’utilisateur n’est pas admin, le formulaire de création est désactivé et une option ‘Ajouter sans l’enregistrer’ (chemin B) est proposée.
• Bouton : “Ingrédient introuvable ? Créer maintenant”.
• Formulaire complet : name, category, unit_group, base_unit (+ optionnels aliases[], season_months[]).
• Switch “Ajouter à ma base d’ingrédients” : ON pour créer l’ingrédient en base.
• Action : crée l’Ingredient puis un GroceryItem source: :manual lié à ingredient_id (quantité convertie en base, bon rayon).

Important v1 : un ajout via pop-up n’est pas relié à un menu_recipe_id (à-côté utilisateur).

---

7. Sécurité & autorisations
   • GroceryListPolicy : lecture/édition si menu.user == current_user.
   • Création d’ingredients : réservé admin
   o Création via la pop up.
   o Tout le monde peut ajouter des ingrédients en mode manual mais seul l’admin peut créer un nouvel ingrédient à enregistrer dans la base (le “switch ON” → vérifie current_user.admin?).

---

8. UX (composants)
   • Vue principale : sections par rayon ; dans chaque section, lignes GroceryItem :
   o [ ] check – nom – quantité humanisée – ✎ (éditer) – 🗑 (supprimer la ligne)
   • Barre d’actions :
   o Bouton “Ajouter une course” (ouvre la pop-up)
   • Édition quantité (✎) :
   o Petite UI : champ quantité + sélecteur d’unité compatible (ex. pour mass: g/kg ; spoon: càc/càs/pincée)
   o Conversion vers base à l’enregistrement, mise à jour de la ligne.

---

9. TDD — Scénarios d’acceptation (Gherkin)
   Feature: Liste de courses consolidée

Background:
Given un menu enregistré avec plusieurs repas
And chaque repas a un number_of_people propre (override possible)
And les recettes ont des preparations en unités de base (g, ml, piece, cac)

Scenario: Génération et affichage par rayons
When j’ouvre la page "Liste de courses" du menu
Then je vois les sections par rayon (fruits_legumes, boucherie, ...)
And chaque ligne affiche: case à cocher, nom ingrédient, quantité humanisée, icône stylet

Scenario: Agrégation et humanisation
Given deux repas utilisent "Pâtes" (mass, g) totalisant 3000 g
When la liste est affichée
Then je vois "Pâtes — 3 kg" (zéro inutile supprimé)

Scenario: Spoons (càs, càc, pincée)
Given trois recettes demandent "Paprika" (spoon: cac) totalisant 5 cac
When la liste est affichée
Then je vois "Paprika — 1 càs 2 càc"

Scenario: Édition inline d’une quantité
Given "Lait" (volume) s’affiche "1,5 L"
When je clique sur ✎ et saisis "500 ml"
Then la ligne affiche "0,5 L" (ou "500 ml" selon humanisation)
And la modification est persistée

Scenario: Cocher une ligne
When je coche "Pâtes — 3 kg"
Then la ligne passe en "coché"
And c’est persisté

Scenario: Ajouter une course via ingrédient existant
When je clique "Ajouter une course"
And je recherche "Tomates" et je choisis l’ingrédient existant (rayon fruits_legumes)
And je saisis quantité "500 g"
And je valide
Then une ligne "Tomates — 500 g" apparait dans la section "fruits_legumes"

Scenario: Créer un nouvel ingrédient dans la pop-up
When je clique "Ajouter une course"
And je clique "Créer un ingrédient"
And je saisis nom "Feuilles de gélatine", rayon "epicerie_sucree", unit_group "count" (piece)
And je valide l’ingrédient
And je saisis quantité "6 pièces"
And je valide l’ajout
Then une ligne "Feuilles de gélatine — 6" apparait dans "epicerie_sucree"

Scenario: Voir la liste recalculée après enregistrement d’un menu (depuis UC2)
Given j’ai modifié un menu persisté et cliqué “Enregistrer mes modifications”
And j’ai confirmé la modal
Then j’arrive sur la page "Liste de courses" déjà recalculée
And seules les lignes generated ont été recalculées ; les lignes manual sont conservées

---

10. Specs de services (exemples RSpec)
    A. Groceries::BuildForMenu
    Responsable : agréger les ingrédients d’un menu en base_unit, puis humaniser pour l’UI.
    RSpec.describe Groceries::BuildForMenu do
    subject(:call) { described_class.call(menu_id: menu.id) }

let(:menu) { create(:menu) }

it "additionne en base puis humanise (g→kg, ml→L, cac→càs/càc/pincée)" do # Prépare 2 repas qui totalisent 3000 g de pâtes # + 5 cac de paprika # + 1500 ml de lait # (… factories raccourcies pour l’exemple …)
list = call.value!
expect(find_item(list, "Pâtes").display).to eq("3 kg")
expect(find_item(list, "Paprika").display).to eq("1 càs 2 càc")
expect(find_item(list, "Lait").display).to eq("1,5 L")
end

it "groupe par rayon" do
list = call.value!
expect(list.sections.map(&:category)).to include("fruits_legumes", "epicerie_sale")
end
end
B. Groceries::Humanize (purement fonctionnel)
• Entrée : unit_group, quantity_base
• Sortie : quantity_display, unit_display (string lisible)
Cas de test :
• 3000 g → 3 kg ; 1500 ml → 1,5 L ;
• 5 cac → 1 càs 2 càc ;
• 0,5 cac → 2 pincées ; 0,25 cac → 1 pincée ;
• 2 piece → 2.
C. Lists::Regenerate
• Recalcule la liste depuis le menu en supprimant uniquement les GroceryItems source = :generated, puis en les reconstruisant.
• Ne touche pas aux GroceryItems source = :manual.

D. Lists::AddItem (A) & Lists::CreateIngredientAndAddItem (B)
• A : prend ingredient_id, (quantity, input_unit) → convertit en quantity_base → crée GroceryItem au bon rayon.
• B : crée un nouvel Ingredient (nom, rayon, unit_group, base_unit, aliases?, season_months?) puis chaîne vers A.

---

11. Modèle de données (champs conseillés)
    ingredients
    • name (uniq), category (enum rayon), unit_group (enum), base_unit (string), season_months (int[]), aliases (jsonb)
    grocery_items
    • menu_id (FK)
    • ingredient_id (FK, nullable si tu acceptes des lignes totalement libres)
    • name (string, seulement si ingredient_id nul)
    • unit_group (enum)
    • base_unit (string)
    • quantity_base (decimal(10,3))
    • checked (bool, défaut false)
    • category (enum, copié depuis ingredient si présent)
    • menu_recipe_id (FK nullable, option traçabilité)
    • Timestamps
    • CHECK: (ingredient_id IS NOT NULL OR name IS NOT NULL)
    • Contraintes : quantity_base >= 0, FKs, index (menu_id, ingredient_id)
    •

---

12. Routing / contrôleurs (idée)
    GET /menus/:id/groceries -> GroceriesController#show (affiche)

# La régénération est orchestrée côté UC2 via POST /menus/:id/save_and_regenerate,

# puis redirection vers GET /menus/:id/groceries.

# Inlines

PATCH /grocery_items/:id -> GroceryItemsController#update (quantity, checked)
DELETE /grocery_items/:id -> GroceryItemsController#destroy

# Pop-up "Ajouter une course"

POST /grocery_items/add_existing -> GroceryItemsController#add_existing
POST /grocery_items/create_and_add -> GroceryItemsController#create_and_add_ingredient

---

13. Nomenclature “rayons” (enum proposé)
    • fruits_legumes, boucherie, poissonnerie, charcuterie,
    • fromage_cremerie, epicerie_sale, epicerie_sucree,
    • boulangerie, surgeles, boissons, entretien
    (à adapter à tes habitudes ; l’important = liste fermée)

---

14. Checklist PO/QA
    • Agrégation correcte avec overrides de personnes par repas.
    • Humanisation conforme (kg/L ; mix càs/càc ; pincées).
    • Aucune décimale “zéro inutile”.
    • Affichage par rayon + cases à cocher + édition stylée.
    • Ajouter une course :
    o voie ingrédient existant (conversion OK)
    o voie création d’ingrédient dans la pop-up (avec rayon) puis ajout
    • Après enregistrement d’un menu (UC2), la liste affichée est recalculée (Option A : only generated), et les cases des lignes recalculées sont décochées.
    • Sécurité : seul le propriétaire du menu peut voir/éditer.

---

15. Notes pédagogiques (pour bien coder)
    • Toujours convertir en base avant d’additionner.
    • Humaniser uniquement à l’affichage (ne pas convertir en base inverse au stockage).
    • Spoons : garde des règles stables (càs=3 càc ; pincée=0,25 càc). Ce sont des approximations culinaires simples et suffisantes en v1.
    • L’édition utilisateur modifie quantity_base (puis tu ré-humanises).
    • La régénération écrase ; c’est assumé et annoncé.
