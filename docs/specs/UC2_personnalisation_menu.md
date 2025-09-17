UC2 — Personnalisation du menu
Version : 1.0
Contexte : EasyMeal (Rails 7.2), Devise, Pundit, Haml, Turbo/Stimulus, Tailwind (option), RSpec.
Prérequis :
• UC1 a produit une proposition (MenuDraft) non persistée, déjà interactive.
• L’utilisateur peut aussi éditer un menu enregistré (persisté) — les mêmes actions sont disponibles.

---

0. Objectif métier
   Permettre à l’utilisateur de façonner son menu jusqu’à ce qu’il corresponde à ce qu’il veut réellement, dès la V1, via 4 actions simples, disponibles dans la proposition (draft) et sur un menu enregistré :

1) Supprimer un repas
2) Remplacer un repas aléatoirement (en respectant les 3 paramètres initiaux : régime, nombre de repas n/b—pas utilisé ici—et priorité saison, sans doublon)
3) Modifier le nombre de personnes d’un repas (override local)
4) Ajouter un repas
   o Aléatoire (non dupliqué, priorité saison)
   o Manuel (choisi dans la base de recettes via Ransack)
   Spécifique menus persistés : en cliquant “Enregistrer mes modifications”, une alerte indique que la liste de courses sera recalculée (option A UC3 : seuls les generated sont réinitialisés, les manual sont conservés).
   • OK → on persiste les changements, on régénère la liste, puis redirection vers la page Liste de courses mise à jour.
   • Annuler → on reste sur le menu, avec la possibilité d’annuler les modifications (retour à l’état enregistré).

---

1. Glossaire (rappel)
   • MenuDraft : proposition en mémoire (UC1).
   • Menu : menu persisté (menus + menu_recipes).
   • Meal : un repas du menu : recipe + number_of_people local (override).
   • Pools :
   o A = saison (recettes “de saison” au mois courant)
   o B = hors saison (ou sans info)

---

2. Portée (in / out)
   Inclus
   • Les 4 actions ci-dessus dans le draft et sur un menu enregistré.
   • Préservation de la non-duplication des recettes dans un même menu.
   • Priorité saison lors des remplacements/ajouts aléatoires (ne bloque jamais).
   • Conservation du nb de personnes local lors d’un remplacement.
   Exclus
   • Création de la liste de courses (UC3).
   • Partage / Archive (UC7).

---

3. Acteurs & sécurité
   • Acteur : utilisateur connecté.
   • Autorisations :
   o Draft : attaché à la session utilisateur (pas de partage).
   o Menu persisté : MenuPolicy — propriétaire uniquement.

---

4. Entrées / sorties (contrats)
   Entrées (actions)
   • menu_context : :draft ou :persisted (le contrôleur sait dans quel contexte on est)
   • Cibles : meal_index ou menu_recipe_id selon le contexte.
   • Actions :
   o remove_meal
   o replace_random (option seed pour tests)
   o update_meal_people(people)
   o add_meal_random
   o add_meal_manual(recipe_id)
   Sorties
   • Draft : MenuDraft muté, re-rendu (Turbo Stream).
   • Persisté :
   o Sur actions unitaires : modifications en DB sur menu_recipes.
   o Sur “Enregistrer mes modifications” : modal de confirmation →
    OK : persistance, régénération de la liste (UC3/Option A), redirect vers la liste de courses.
    Annuler : rester sur la page menu (aucune persistance), possibilité “Annuler les modifications”.

---

5. Règles métier

1) Non-duplication : dans la proposition comme dans le menu sauvegardé, une recette ne doit pas apparaître 2 fois.
   o Si l’utilisateur veut réutiliser la même recette, il passe par UC1 (génération différente) ou on lèvera un message “Recette déjà présente”.
2) Priorité saison (mois courant) pour ajout/remplacement aléatoire :
   o Chercher d’abord dans A (saison) exclus les recettes déjà dans le menu,
   o puis B (hors saison) si A est vide.
   o Jamais d’échec “bloquant” — mais message si aucun candidat (tout épuisé).
3) Remplacement :
   o conserve le number_of_people local du repas remplacé,
   o respecte le diet du menu.
4) Modification du nb de personnes d’un repas :
   o valeur ≥ 1,
   o ne modifie que ce repas.
5) Ajout d’un repas :
   o Aléatoire : tire une recette compatible (A→B), non dupliquée, initialise number_of_people au défaut du menu.
   o Manuel : l’utilisateur choisit une recette sur /recipes (Ransack) → bouton “Ajouter au menu” → revient au contexte avec la nouvelle carte initialisée au défaut du menu.
6) Édition d’un menu persisté — enregistrement & régénération synchrones :
   o Clic “Enregistrer mes modifications” → modal :
   • “La liste de courses liée à ce menu sera recalculée. Vos ajouts manuels seront conservés ; les quantités des lignes générées seront réinitialisées.”
   o OK :
7) Persister les changements sur menu_recipes,
8) Régénérer la liste (UC3, Option A : écrase generated, conserve manual, ignore les edits sur generated),
9) Rediriger vers la liste de courses recalculée.
   o Annuler :
   • rester sur l’écran du menu (pas de sauvegarde),
   • bouton/icône “Annuler les modifications” disponible pour revenir à l’état enregistré initial.

---

6. UX (cartes & interactions)
   • Carte repas (draft & persisté) :
   o Photo, titre (+ badge “de saison” si applicable)
   o Icônes : 🗙 Supprimer | 🔄 Remplacer
   o Nb de personnes : “4 pers” cliquable (−/+) via Stimulus ; validation instantanée (Turbo).
   • Bouton “Ajouter un repas” :
   o Choix “Aléatoire” ou “Choisir dans la base” (redirige /recipes, conserve retour au menu).
   • Persisté — actions globales :
   o “Enregistrer mes modifications” → modal (cf. §5.6) → OK ⇒ redirect vers la liste de courses recalculée ; Annuler ⇒ on reste.
   o “Annuler les modifications” (toujours visible) : restaure l’état enregistré du menu (réinitialise les changements non sauvegardés).
   • Snackbars/messages :
   o “Plus de recettes disponibles à ajouter/remplacer” si pools épuisés
   o “Recette déjà présente dans le menu” si tentative de doublon manuel

---

7. TDD — Scénarios d’acceptation (Gherkin)
   Feature: Personnaliser un menu (draft & persisté)

Background:
Given un utilisateur connecté
And un MenuDraft de 6 repas (diet=vegetarien, default_people=4)
And un menu persisté similaire pour d’autres scénarios
And le mois courant est août

Scenario: Supprimer un repas (draft)
When je supprime le repas #3
Then le draft contient 5 repas
And aucune autre carte n’est modifiée

Scenario: Remplacer aléatoirement (draft)
Given des recettes vegetariennes de saison et hors saison
When je remplace le repas #2
Then #2 devient une recette vegetarienne non dupliquée
And s'il reste des recettes de saison disponibles, une de saison est choisie
And le nb de personnes du repas #2 est conservé

Scenario: Modifier le nb de personnes (draft)
When je passe le repas #4 à "2 pers"
Then seul #4 affiche "2 pers"
And tous les autres restent à "4 pers"

Scenario: Ajouter un repas aléatoire (draft)
When j'ajoute un repas aléatoirement
Then une nouvelle carte apparait
And la recette n’est pas déjà présente
And le nb de personnes = 4 (défaut du menu)

Scenario: Ajouter un repas manuel depuis /recipes (draft)
When je choisis "Salade grecque" dans /recipes et clique "Ajouter au menu"
Then je reviens au draft avec une carte supplémentaire "Salade grecque"
And elle est initialisée à "4 pers"

Scenario: Pools épuisés pour remplacement/ajout
Given toutes les recettes compatibles sont déjà utilisées
When je tente de remplacer ou d’ajouter
Then je vois "Plus de recettes disponibles"
And rien n’est changé

# Éditions sur menu persisté

Scenario: Remplacer sur un menu enregistré
Given j’ouvre un menu enregistré de 6 repas
When je remplace le repas #1
Then le repas #1 change de recette en DB
And je vois un bandeau "Modifications non enregistrées"
When je clique "Enregistrer mes modifications" et je confirme dans la modal
Then je suis redirigé vers la page "Liste de courses" recalculée

---

8. Specs de services (exemples RSpec)
   A. Draft — Menus::DraftActions
   RSpec.describe Menus::DraftActions do
   let(:draft) { build(:menu_draft, :vegetarien, default_people: 4, meals_count: 6) }

it "supprime un repas par index" do
expect { described_class.remove_meal(draft:, index: 2) }
.to change { draft.meals.size }.from(6).to(5)
end

it "remplace aléatoirement en priorisant la saison et sans doublon" do
seasonal_pool = create_list(:recipe, 3, :vegetarienne, :seasonal_now)
other_pool = create_list(:recipe, 10, :vegetarienne, :non_season)
old_people = draft.meals[1].number_of_people

    described_class.replace_random(draft:, index: 1, seasonal_pool:, other_pool:, seed: 123)

    expect(draft.meals[1].recipe).to be_present
    expect(draft.meals.map { |m| m.recipe.id }.uniq.size).to eq(draft.meals.size)
    expect(draft.meals[1].number_of_people).to eq(old_people)

end

it "met à jour le nb de personnes local" do
described_class.update_meal_people(draft:, index: 3, people: 2)
expect(draft.meals[3].number_of_people).to eq(2)
end

it "ajoute un repas aléatoire non dupliqué" do
seasonal_pool = create_list(:recipe, 1, :vegetarienne, :seasonal_now)
other_pool = create_list(:recipe, 10, :vegetarienne, :non_season)

    described_class.add_random(draft:, seasonal_pool:, other_pool:, seed: 999)

    expect(draft.meals.size).to eq(7)
    expect(draft.meals.last.number_of_people).to eq(4)

end

it "ajoute un repas manuel et empêche le doublon" do
chosen = create(:recipe, :vegetarienne)
described_class.add_manual(draft:, recipe: chosen)
expect(draft.meals.last.recipe).to eq(chosen)

    expect {
      described_class.add_manual(draft:, recipe: chosen)
    }.to raise_error(Menus::DraftActions::DuplicateRecipe)

end
end
B. Persisté — Menus::Edit
RSpec.describe Menus::Edit do
let(:menu) { create(:menu, :vegetarien, default_people: 4) }
let!(:menu_recipes) { create_list(:menu_recipe, 6, menu:) }

it "supprime un menu_recipe" do
expect {
described_class.remove_meal(menu:, menu_recipe_id: menu_recipes.second.id)
}.to change { menu.menu_recipes.count }.by(-1)
end

it "remplace un menu_recipe en conservant le nb de personnes" do
old_people = menu_recipes.first.number_of_people
candidate = create(:recipe, :vegetarienne)

    described_class.replace_random(menu:, menu_recipe_id: menu_recipes.first.id, candidate_finder: -> { candidate })

    menu_recipes.first.reload
    expect(menu_recipes.first.recipe_id).to eq(candidate.id)
    expect(menu_recipes.first.number_of_people).to eq(old_people)

end

it "met à jour le nb de personnes d’un menu_recipe" do
described_class.update_meal_people(menu:, menu_recipe_id: menu_recipes.third.id, people: 2)
expect(menu_recipes.third.reload.number_of_people).to eq(2)
end

it "ajoute un repas aléatoire non dupliqué, initialisé à la valeur par défaut du menu" do
candidate = create(:recipe, :vegetarienne)
described_class.add_random(menu:, candidate_finder: -> { candidate })

    new_mr = menu.menu_recipes.order(:created_at).last
    expect(new_mr.recipe_id).to eq(candidate.id)
    expect(new_mr.number_of_people).to eq(menu.number_of_people)

end
end

---

9. Modèle & persistance (rappels utiles)
   • menu_recipes :
   o menu_id FK, recipe_id FK,
   o number_of_people not null,
   o unique (menu_id, recipe_id) pour empêcher les doublons (v1 stricte)
    (si tu veux autoriser 2× la même recette à terme, il faudra un champ position ou occurrence et retirer l’unicité)

---

10. Routage & contrôleurs (idée)

# Draft (session/Redis)

POST /menus/draft/remove -> Menus::DraftController#remove
POST /menus/draft/replace -> Menus::DraftController#replace
PATCH /menus/draft/update_people -> Menus::DraftController#update_people
POST /menus/draft/add_random -> Menus::DraftController#add_random
POST /menus/draft/add_manual -> Menus::DraftController#add_manual

# Persisté (DB)

POST /menus/:id/remove_meal -> Menus::MenusController#remove_meal
POST /menus/:id/replace_meal -> Menus::MenusController#replace_meal
PATCH /menus/:id/update_meal_people -> Menus::MenusController#update_meal_people
POST /menus/:id/add_meal_random -> Menus::MenusController#add_meal_random
POST /menus/:id/add_meal_manual -> Menus::MenusController#add_meal_manual
POST /menus/:id/save_and_regenerate -> Menus::MenusController#save_and_regenerate

# Transaction: persist changes -> Lists::Regenerate (UC3 Option A) -> redirect /menus/:id/groceries

• UI : mêmes boutons/icônes dans les deux contextes ; seules les routes changent.

---

11. Checklist PO/QA
    • Supprimer/Remplacer/Modifier nb pers fonctionnent dans draft et persisté.
    • Aucun doublon n’est possible.
    • Remplacer conserve le nb de personnes local.
    • Ajouter (aléatoire/manuel) initialise toujours au nb de personnes par défaut du menu.
    • Priorité saison effective (A→B), jamais bloquante.
    • Messages clairs en cas de pools épuisés ou tentative de doublon.
    • Save sur menu persisté ⇒ modal puis régénération + redirect vers la liste.

---

12. Notes pédagogiques
    • Même logique, deux contextes : le draft (session) et le persisté (DB). Les services sont parallèles : DraftActions vs Menus::Edit.
    • Non-duplication : protège avec une contrainte DB côté persisté, et une vérif logicielle côté draft.
    • Priorité saison : un détail UX qui rend les propositions plus pertinentes, sans frustrer (jamais bloquant).
    • Nb de personnes : pense “valeur par repas” dès maintenant — c’est ce qui alimente UC3 (quantités) et la fiche recette.
