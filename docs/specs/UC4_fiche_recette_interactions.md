UC4 — Fiche Recette & interactions
Version : 1.0
Contexte : EasyMeal (Rails 7.2), Devise, Pundit, Haml, Turbo/Stimulus, Tailwind (option), Ransack (navigation), ActiveStorage(+Cloudinary), RSpec.
Prérequis :
• Modèles Recipe, Ingredient, Preparation(recipe↔ingredient, quantity_base), FavoriteRecipe, Review (notes/commentaires), Menu, MenuRecipe.
• Unités & conversions (UC3) : mass(g), volume(ml), count(piece), spoon(cac) + humanisation (kg / L / càs+càc / pincée).

---

0. Objectif métier
   Permettre à l’utilisateur de consulter et interagir avec une recette :

1) Voir : photo, titre, tags, temps (prépa/cuisson), difficulté/prix (si renseignés), ingrédients calculés pour un nombre de personnes déterminé, et étapes.
2) Ajuster le nombre de personnes pour recalculer les quantités en live :
   o Hors contexte menu : c’est local à la page (pas de persistance).
   o Dans le contexte d’un menu (via menu_id + menu_recipe_id) : la modification persiste sur le MenuRecipe.number_of_people (UC2) et ne régénère pas la liste immédiatement (UC3) → on propose un CTA “Mettre à jour la liste maintenant” qui appelle save_and_regenerate.
3) Actions sociales :
   o Favori (toggle ⭐),
   o Noter (★ 1..5, 1 avis par user/recette, éditable),
   o Commenter (texte), avec pagination simple (Pagy).

---

1. Glossaire
   • Recipe : possède default_servings, prep_time_minutes, cook_time_minutes, diet, tags, appliance?, source_url?, photo(ActiveStorage).
   • Preparation : ingredient_id, quantity_base (en unité de base du ingredient.unit_group).
   • Contextes d’affichage :
   o Standalone : /recipes/:id (aucun menu associé).
   o Menu Contexte : /menus/:menu_id/recipes/:id?menu_recipe_id=... (on sait combien de personnes via le MenuRecipe et on peut persister la modification).

---

2. Portée (in/out)
   Inclus
   • Affichage complet d’une recette : photo, méta, ingrédients recalculés, étapes.
   • Choix nb de personnes (slider/input) :
   o Standalone → local (non persistant).
   o Menu → persistant sur MenuRecipe.
   • Actions sociales : Favori, Note (1 par user), Commentaires (CRUD simple pour l’auteur).
   • Tags (affichés en badges, cliquables → /recipes?q[tags_name_eq]).
   • Lien “Retour au menu” si on vient d’un menu.
   Exclus (v1)
   • Nutrition, timers avancés, multi-photos, historique d’édition.

---

3. Acteurs & sécurité
   • Acteur : utilisateur connecté pour Favori / Note / Commenter
   • Autorisations Pundit :
   o RecipePolicy#show : public.
   o FavoriteRecipePolicy : owner-only.
   o ReviewPolicy : create/update/destroy = owner-only.
   o MenuRecipePolicy#update_people : propriétaire du menu.

---

4. Entrées / sorties (contrats)
   Entrées
   • recipe_id (obligatoire).
   • Optionnel contexte menu : menu_id, menu_recipe_id.
   Sorties (UI)
   • Détails recette + ingrédients recalculés pour servings_current:
   o Standalone : servings_current = params[:servings] || recipe.default_servings.
   o Menu : servings_current = menu_recipe.number_of_people.
   • Actions : boutons/toggles Favori, Note ★, Commentaires (liste + form).
   • Si Menu contexte : bandeau “Ce repas est dans ton menu (X pers)” + actions :
   o − / + pour number_of_people (persistant),
   o lien “Mettre à jour la liste maintenant” → POST /menus/:id/save_and_regenerate (modal confirm).

---

5. Règles métier

1) Recalcul des quantités
   • factor = servings_current / recipe.default_servings.
   • Pour chaque preparation: quantity_display = humanize(quantity_base \* factor) selon unit_group (UC3).
   • Aucun zéro inutile ; càs/càc/pincée avec arrondi 0,25 càc.
2) Modification du nb de personnes
   • Standalone : ne persiste pas ; seulement UI (Stimulus), recalcul côté front ou via Turbo Stream.
   • Menu : persiste immédiatement (MenuRecipe.number_of_people, min 1).
   o Après modification : toast “Quantités de la liste non encore mises à jour. [Mettre à jour la liste]” (lien save_and_regenerate).
   o La régénération suit UC3 Option A (écrase generated, conserve manual).
3) Favori
   • Toggle idempotent : create/destroy FavoriteRecipe(user_id, recipe_id).
4) Note & Commentaire
   • Review : rating (1..5), content(texte optionnel), unicité (user_id, recipe_id) (1 avis par user).
   • Moyenne recipe.rating_avg (scope ou champ materialized plus tard).
   • Commentaires paginés (Pagy), ordre desc.
5) Photo
   • recipe.photo via ActiveStorage (@cloudinary service). Variants (taille homogène).

---

6. UX (Haml + Turbo/Stimulus)
   • Header : photo (ratio fixé), titre, tags (badges), temps (prépa/cuisson), diet.
   • Bandeau contexte menu (si présent) :
   o “Ce repas est dans ton menu (X pers)”
   o − / + (Stimulus) → PATCH update_meal_people (persisté)
   o Lien “Mettre à jour la liste maintenant” (→ save_and_regenerate avec modal).
   • Bloc “Ingrédients (pour X personnes)” :
   o Standalone : contrôles − / + locaux (pas de persistence).
   o Liste groupée par rayon (option UX sympa, non obligatoire ici).
   • Bloc “Étapes” : texte structuré (markdown simple éventuel).
   • Actions :
   o ⭐ Favori (toggle)
   o ★ Note (5 radios ou étoiles cliquables) + compteur moyenne
   o 💬 Commentaires (liste + form ; CRUD limité à l’auteur pour edit/del)
   • Liens : “Retour au menu” si contexte menu ; “Voir recettes similaires” (par tags ou diet).

---

7. TDD — Scénarios d’acceptation (Gherkin)
   Feature: Fiche recette et interactions

Background:
Given une recette "Pâtes crémeuses" avec default_servings = 4
And des preparations (g, ml, cac, piece) enregistrées en base
And un utilisateur connecté

Scenario: Afficher une recette en standalone
When j’ouvre /recipes/:id
Then je vois la photo, le titre, les tags, les temps
And le bloc "Ingrédients (pour 4 personnes)"
And les quantités sont humanisées correctement (kg/L/càs+càc/pincée)

Scenario: Changer le nombre de personnes en standalone (non persistant)
When je passe le sélecteur de 4 à 2 personnes
Then les quantités sont recalculées pour 2 pers
And si je recharge la page, ça revient à 4 (default_servings)

Scenario: Ouvrir une recette depuis un menu et voir le contexte
Given un menu M avec menu_recipe MR (number_of_people = 6) pour cette recette
When j’ouvre /menus/M/recipes/:id?menu_recipe_id=MR
Then le bandeau "Ce repas est dans ton menu (6 pers)" est visible
And le bloc ingrédients affiche les quantités pour 6 pers

Scenario: Modifier le nombre de personnes depuis la fiche (contexte menu)
When je clique sur + (6 → 7)
Then MR.number_of_people est persisté à 7
And un toast m’indique "La liste n’est pas à jour" avec un lien "Mettre à jour la liste"
When je clique "Mettre à jour la liste"
Then la liste de courses du menu est régénérée (Option A) et affichée

Scenario: Mettre en favori
When je clique sur "Ajouter aux favoris"
Then un FavoriteRecipe est créé
And le bouton passe en "Retirer des favoris"

Scenario: Noter la recette
When je choisis 5 étoiles et j’enregistre
Then un Review(user, recipe) avec rating=5 est créé
And la moyenne affichée inclut ma note

Scenario: Commenter la recette
When je saisis "Excellent !" et poste
Then mon commentaire apparaît en premier
And je peux le modifier ou le supprimer

Scenario: Unicité de la note par utilisateur
Given j’ai déjà noté la recette
When je soumets une nouvelle note
Then ma note précédente est mise à jour (pas de doublon)

---

8. Specs (exemples RSpec)
   A. Recipes::ScaleIngredients (purement fonctionnel)
   • Entrée : recipe, servings_current.
   • Sortie : liste {ingredient, quantity_display, unit_display} humanisée.
   • Cas : g→kg, ml→L, 5 cac → “1 càs 2 càc”, 0,5 cac → “2 pincées”, arrondi 0,25 càc.
   B. Menus::Edit.update_meal_people
   • Persiste MenuRecipe.number_of_people (≥1).
   • Interdit si user ≠ owner (Pundit).
   C. FavoritesController
   • Toggle create/destroy (idempotent).
   D. ReviewsController
   • create_or_update : unique (user, recipe).
   • Validation rating 1..5.

---

9. Modèle & validations
   • recipes
   o default_servings NOT NULL (≥1)
   o prep_time_minutes?, cook_time_minutes?, diet enum, tags (via recipe_tags)
   o photo (ActiveStorage)
   • preparations
   o ingredient_id, recipe_id, quantity_base DECIMAL(10,3), unit du côté ingrédient (groupe cohérent)
   • favorite_recipes(user_id, recipe_id) unique
   • reviews(user_id, recipe_id) unique, rating 1..5, content?
   • (Option) recipes.rating_avg matérialisé plus tard

---

10. Routing / contrôleurs

# Standalone

GET /recipes -> RecipesController#index (Ransack)
GET /recipes/:id -> RecipesController#show

# Contexte menu (alias show avec params)

GET /menus/:menu_id/recipes/:id -> RecipesController#show (avec menu_recipe_id)

# Actions contexte menu

PATCH /menus/:menu_id/menu_recipes/:id/people -> Menus::MenusController#update_meal_people
POST /menus/:menu_id/save_and_regenerate -> Menus::MenusController#save_and_regenerate

# Favoris

POST /recipes/:id/favorite -> FavoritesController#create
DELETE /recipes/:id/favorite -> FavoritesController#destroy

# Avis

POST /recipes/:id/review -> ReviewsController#create_or_update
DELETE /recipes/:id/review -> ReviewsController#destroy

---

11. UX détails (pratico-pratique)
    • Servings control : un input number (min=1) + boutons − / + (Stimulus).
    • Quantités : liste simple ; si tu veux, regrouper par rayon (sympa et cohérent avec UC3, mais optionnel sur UC4).
    • Messages :
    o “Modifié à 7 pers — liste non à jour” + bouton “Mettre à jour la liste”.
    o Succès/erreur sur Favori / Note / Commentaire avec Turbo Streams.
    • Accessibilité : labels explicites pour − / +, role="status" pour toasts.

---

12. Checklist PO/QA
    • Recalcule correct des ingrédients pour servings_current.
    • Standalone : changement de “pers” non persistant.
    • Menu : changement de “pers” persistant + toast + CTA “Mettre à jour la liste”.
    • CTA “Mettre à jour la liste” → save_and_regenerate (Option A UC3) puis redirect liste.
    • Favori toggle OK.
    • Note ★ : 1 par user, éditable, moyenne affichée.
    • Commentaires : création/édition/suppression par l’auteur, pagination.
    • Photo s’affiche (variant Cloudinary) avec ratio homogène.
    • Pundit : toutes les écritures protégées.

---

13. Notes pédagogiques
    • Toujours recalculer à partir des quantités en base des preparations.
    • Humaniser seulement en sortie (affichage).
    • Séparer les responsabilités :
    o un petit service “scale” (fonctionnel, testable),
    o un contrôleur fin (juste orchestration + Pundit),
    o Stimulus pour l’UX “−/+” fluide.
    • Contexte menu : garde en tête l’enchaînement UC2→UC3 quand on change les “pers”.
