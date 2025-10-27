UC1 — Générer un menu (avec personnalisation immédiate + ajout de repas)
Version : 1.2 (ajout du bouton “Ajouter un repas”)
Contexte : EasyMeal (Rails 7.2), Devise, Pundit, Haml, Turbo/Stimulus, Tailwind (option), Ransack pour la recherche de recettes.

---

0. Objectif métier
   À partir de 3 paramètres — régime, nombre de personnes (défaut), nombre total de repas — l’utilisateur génère une proposition de menu (non persistée), priorisant les recettes de saison au mois courant (sans bloquer si insuffisant).
   Dès la proposition, il peut personnaliser : supprimer, remplacer aléatoirement, modifier le nombre de personnes par repas, ou ajouter un nouveau repas :

1) aléatoire (non dupliqué, priorisant la saison),
2) manuel (choix dans la base de recettes avec filtres + prévisualisation).

---

1. Glossaire (rappel)
   • MenuDraft : proposition de menu en mémoire (non stockée en base tant qu’on n’enregistre pas).
   • Meal : un élément du draft : recipe, number_of_people local (override possible), seasonal_for_current_month (bool).

---

2. Portée (in / out)
   Inclus (UC1)
   • Génération depuis 3 champs.
   • Priorité saison (non bloquante).
   • Personnalisation : supprimer / remplacer aléatoirement / modifier nb de personnes par repas.
   • Nouveau : Ajouter un repas
   o Aléatoire (non dupliqué, priorisant saison)
   o Manuel via page “Toutes les recettes” (Ransack) + fiche recette + bouton “Ajouter au menu”.
   Exclus (hors UC1)
   • Persistance du menu.
   • Liste de courses, partage, archivage.

---

3. Entrées / sorties
   Entrées (formulaire initial)
   • diet (enum), number_of_people (≥1), number_of_meals (≥1).
   Sorties (proposition non persistée)
   • MenuDraft avec meals (taille ≥ number_of_meals si on ajoute des repas).
   • Chaque Meal : recipe, number_of_people (initialisé à la valeur par défaut du menu), seasonal_for_current_month.

---

4. Règles métier (nouveautés incluses)

1) Pas de doublon de recette dans la proposition (y compris après ajouts/remplacements).
2) Priorité saison : remplir d’abord depuis le pool “de saison” (mois courant), puis compléter avec hors saison si besoin.
3) Nombre de personnes par repas :
   o initialisé au nombre de personnes du menu,
   o modifiable par repas,
   o conservé lors d’un remplacement (on garde la valeur locale du repas remplacé).
4) Ajouter un repas — aléatoire :
   o tire une recette compatible régime, non encore présente, en essayant pool saison puis pool hors saison ;
   o initialise number_of_people à la valeur par défaut du menu.
5) Ajouter un repas — manuel :
   o l’utilisateur est redirigé vers /recipes (index) avec Ransack (filtres par nom, diet, tags, temps, etc.),
   o peut ouvrir une fiche recette (show) et cliquer “Ajouter au menu”,
   o retour au draft avec un repas en plus, initialisé à default_people du menu.
6) Épuisement des candidats (aléatoire) : message “Plus de recettes disponibles à ajouter/remplacer pour ce critère”.

---

5. UX (cartes & navigation)
   Carte “repas” (dans la proposition)
   • Vignette photo
   • Titre + badge “de saison” (si applicable)
   • Icônes : 🗙 Supprimer, 🔄 Remplacer (aléatoire)
   • Nb de personnes (ex. “4 pers”) cliquable (− / + via Stimulus)
   Bouton principal (au-dessus ou en bas de la liste)
   • “Ajouter un repas” (wording à confirmer)
   o Menu déroulant ou pop-up avec 2 choix :

1) “Ajouter aléatoirement”
2) “Choisir dans la base”
    redirige vers /recipes
    page index avec Ransack (filtres, tri)
    CTA “Ajouter au menu” sur chaque carte recette (ou dans la fiche)
    retour au MenuDraft (via param/return path, ex. session)
   Technique : conserver le draft en session (ou Redis si tu préfères), clé par utilisateur. Les actions de personnalisation (remove/replace/add/update_people) mutent le draft en mémoire, puis re-rendent la page via Turbo Streams.

---

6. TDD — Scénarios d’acceptation (Gherkin)
   Feature: Ajouter des repas à la proposition

Background:
Given une proposition de menu avec 6 repas (diet: vegetarien, default_people: 4)
And le mois courant est août
And la base contient des recettes vegetariennes de saison et hors saison

Scenario: Ajouter un repas aléatoire (priorité saison, sans doublon)
When je clique sur "Ajouter un repas" puis "Aléatoire"
Then un nouveau repas apparait en bas de la liste
And sa recette respecte le régime "vegetarien"
And si des recettes de saison sont encore disponibles, l’algorithme en choisit une
And la recette n’est pas déjà présente dans le menu
And le repas affiche "4 pers" (valeur par défaut du menu)

Scenario: Ajouter un repas manuel (depuis la base de recettes)
When je clique sur "Ajouter un repas" puis "Choisir dans la base"
And j’arrive sur la page "Toutes les recettes" avec des filtres
And je filtre par "vegetarien" et "rapide"
And je clique sur "Ajouter au menu" sur la recette "Salade grecque"
Then je reviens à ma proposition de menu
And un nouveau repas "Salade grecque" apparait
And ce repas affiche "4 pers"

Scenario: Ajouter aléatoire alors que tous les candidats sont épuisés
Given toutes les recettes vegetariennes disponibles sont déjà dans la proposition
When je clique sur "Ajouter un repas" -> "Aléatoire"
Then je vois "Plus de recettes disponibles à ajouter"
And aucun repas n’est ajouté

Scenario: Remplacer puis ajouter
When je remplace aléatoirement le repas #2
And j’ajoute un repas aléatoire
Then le menu ne contient aucun doublon
And chaque nouveau repas est initialisé à "4 pers"

Scenario: Modifier le nombre de personnes d’un nouveau repas
When j’ajoute un repas (aléatoire ou manuel)
And je change ce repas à "2 pers"
Then ce repas affiche "2 pers"
And les autres conservent leur valeur

---

7. Specs de service — exemples (RSpec)
   A. Menus::Generate (inchangé + extension)
   • Déjà couvert : sélection initiale (priorité saison), pas de doublons, seed optionnel.
   • À ajouter : méthode utilitaire exposant les pools pour réutilisation.

# app/services/menus/generate.rb (idée d’API interne)

class Menus::Generate

# ...

def pools_for(diet:)
current_month = Date.current.month
a = Recipe.compatible_with(diet).seasonal_for(current_month)
b = Recipe.compatible_with(diet).where.not(id: a.select(:id))
[a, b]
end
end
B. MenuDraft (mutations côté draft)
RSpec.describe MenuDraft do
let(:default_people) { 4 }
let(:recipes) { create_list(:recipe, 6, :vegetarienne, :with_any_ingredient) }
let(:draft) do
MenuDraft.build_from_selection(
diet: :vegetarien,
number_of_people: default_people,
selection: recipes
)
end

it "ajoute un repas aléatoire non dupliqué (priorisant saison)" do
seasonal_pool = create_list(:recipe, 2, :vegetarienne, :with_season_ingredient_for_current_month)
other_pool = create_list(:recipe, 5, :vegetarienne, :with_non_season_ingredient)

    # Service externe qui choisit la recette suivante
    added = Menus::DraftActions.add_random_meal(draft:, seasonal_pool:, other_pool:)
    expect(added).to be_truthy
    expect(draft.meals.size).to eq(7)
    expect(draft.meals.map { |m| m.recipe.id }.uniq.size).to eq(7)
    expect(draft.meals.last.number_of_people).to eq(default_people)

end

it "ajoute un repas manuel (recette choisie), initialisé à la valeur par défaut" do
chosen = create(:recipe, :vegetarienne, :with_any_ingredient)
Menus::DraftActions.add_manual_meal(draft:, recipe: chosen)
expect(draft.meals.last.recipe).to eq(chosen)
expect(draft.meals.last.number_of_people).to eq(default_people)
end

it "refuse d'ajouter une recette déjà présente" do
chosen = draft.meals.first.recipe
expect {
Menus::DraftActions.add_manual_meal(draft:, recipe: chosen)
}.to raise_error(Menus::DraftActions::DuplicateRecipe)
end
end
C. Menus::DraftActions (services ciblés)
• add_random_meal(draft:, seasonal_pool:, other_pool:)
o essaie seasonal_pool \ present_ids puis other_pool \ present_ids
o si vide → NoCandidatesToAdd + message UX
o ajoute Meal avec number_of_people = draft.default_people
• add_manual_meal(draft:, recipe:)
o refuse si recipe.id déjà présent
o ajoute Meal avec number_of_people = draft.default_people

---

8. Routing / Contrôleur (suggestion)
   GET /menus/new -> MenusController#new (form)
   POST /menus/preview -> MenusController#preview (génère le draft en session)

# Personnalisation (Turbo / POST/PATCH)

POST /menus/draft/remove -> Menus::DraftController#remove
POST /menus/draft/replace -> Menus::DraftController#replace
POST /menus/draft/add_random -> Menus::DraftController#add_random
POST /menus/draft/add_manual -> Menus::DraftController#add_manual
PATCH /menus/draft/update_people -> Menus::DraftController#update_people

# Recettes

GET /recipes -> RecipesController#index (Ransack)
GET /recipes/:id -> RecipesController#show
POST /recipes/:id/add_to_draft -> Menus::DraftController#add_manual
• Stockage du draft : session[:menu_draft] (payload JSON sérialisé) ou Redis.
• Retour depuis /recipes : POST /recipes/:id/add_to_draft puis redirect 302 → /menus/preview.

---

9. Points d’attention pédagogiques
   • Toujours empêcher les doublons lors des ajouts/remplacements : compare les IDs présents dans draft.meals.
   • Initialiser le nb de personnes des repas ajoutés à la valeur par défaut du menu (puis modifiable).
   • Prioriser la saison sans bloquer : on essaie d’abord le pool saison, puis on bascule hors saison.
   • Rester simple : toute la “logique de tirage” vit dans de petits services (Generate, DraftActions), testables séparément.

---

10. Checklist PO/QA (mise à jour)
    • Bouton “Ajouter un repas” présent.
    • Aléatoire : ajoute un repas non dupliqué, compatible diet, priorisant la saison ; affiche default_people.
    • Manuel : depuis /recipes (Ransack + show), “Ajouter au menu” revient au draft et ajoute la recette, sans doublon, avec default_people.
    • Remplacements successifs et ajouts multiples : jamais de doublon.
    • Message clair quand il n’y a plus de candidats à ajouter/remplacer.
    • Le nb de personnes par repas reste modifiable à tout moment dans le draft.
