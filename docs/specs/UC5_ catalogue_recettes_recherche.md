UC5 — Catalogue & Recherche de recettes (Ransack)
Version : 1.0
Contexte : Rails 7.2, Ransack, Pagy, Haml, Turbo/Stimulus, Tailwind (option), ActiveStorage(+Cloudinary), RSpec.
Prérequis : Modèles Recipe, Ingredient, Preparation, RecipeTag (+ tags seeds semi-contrôlés), FavoriteRecipe, Review.

---

0. Objectif métier
   Permettre à l’utilisateur de parcourir et trouver rapidement une recette :
   • via une recherche texte et des filtres utiles (régime, temps, tags, saisonnalité simple, ingrédients inclus/exclus),
   • avec tri (pertinence/temps/popularité), pagination,
   • et des actions rapides : voir la fiche, ajouter au draft/menu (UC1/UC2), favori ⭐.

---

1. Portée (in / out)
   Inclus
   • Page /recipes : champ de recherche, filtres, tri, pagination (Pagy).
   • Cartes recettes : photo, titre, tags, durée totale (prépa+cuisson), note moyenne ★, bouton “Ajouter au menu” (si contexte draft/menu présent) + ⭐ favori.
   • Prévisualisation rapide (modal “aperçu”) : photo + ingrédients pour default_servings.
   • Filtre saisonnalité : “mettre en avant les recettes de saison” (non bloquant).
   • Filtres ingrédients inclus / exclus (nom/alias d’ingrédient).
   • Raccourci “Afficher seulement mes favoris”.

---

2. Glossaire
   • Recette “de saison (mois courant)” : au moins 1 ingredient dont season_months contient Date.current.month.
   • Contexte draft/menu : présence de session[:menu_draft] (UC1) ou de menu_id (UC2) pour activer “Ajouter au …. ” sur les cartes.

---

3. Acteurs & sécurité
   • Lecture publique (ou uniquement utilisateur connecté si tu préfères).
   • Actions ⭐/“Ajouter au menu” : connecté.
   • Pundit : RecipePolicy#show? public ; actions add_to_draft/add_to_menu → propriétaire du draft/menu (UC2).

---

4. Entrées / Filtres (Ransack)
   Paramètres Ransack (q[...]) + params simples :
   • Texte : name_or_tags_name_or_ingredients_name_i_cont
   • Régime : diet_eq (enum)
   • Temps :
   o prep_time_minutes_lteq
   o cook_time_minutes_lteq
   o (ou total_time_minutes_lteq via scope calculé)
   • Tags : tags_name_in[]
   • Appareil : appliance_eq (option)
   • Favoris (moi) : only_favorites=true
   • Ingrédients :
   o INCLUDE : with_ingredient_names[]=tomate (scope)
   o EXCLUDE : without_ingredient_names[]=lait (scope)
   • Saisonnalité : seasonal_priority=true → n’est pas un where bloquant : on booste l’ordre d’affichage.
   • Tri :
   o s=name asc/desc (alpha),
   o s=total_time_minutes asc,
   o s=rating_avg desc,
   o s=seasonal_priority desc, rating_avg desc (si flag saison actif).

---

5. Sorties (UI)
   • Liste paginée (Pagy) de cartes recette :
   o vignette (variant Cloudinary),
   o titre, tags (badges), temps total, moyenne ★ (arrondi 0,1),
   o badge (ou petite icone) “de saison” si applicable,
   o actions : ⭐ favori toggle ; “Ajouter au menu” (si contexte)
   o lien “Voir” (fiche UC4) ou “Aperçu” (modal).
   • Barre latérale filtres + résumés actifs (chips amovibles).

---

6. Règles métier

1) Saisonnalité en priorité (non bloquante)
   Si seasonal_priority=true, on booste l’ordre (CASE WHEN seasonal THEN 1 ELSE 0 END DESC) au lieu d’exclure les autres.
2) Ingrédients include/exclude
   • with_ingredient_names: join preparations→ingredients + ILIKE ANY (aliases) (simple : name + aliases @> [...]).
   • without_ingredient_names: anti-join / NOT EXISTS.
3) Temps total = prep_time_minutes.to_i + cook_time_minutes.to_i (scope SQL ou méthode + colonne matérialisée plus tard si besoin perfs).
4) Favoris
   only_favorites=true joint favorite_recipes scoping par current_user.
5) Tri par popularité (option)
   rating_avg desc, reviews_count desc. (On peut matérialiser plus tard.)

---

7. UX (Haml + Stimulus)
   • Header : champ recherche + bouton “Filtres”.
   • Filters panel :
   o Régime (pills), Temps (sliders), Tags (multi-select), Ingrédients inclure/exclure (token input avec autocomplete), Appareil (select), “Mettre en avant la saison” (switch).
   o Boutons “Réinitialiser” / “Appliquer”.
   • Top bar : chips des filtres actifs + select de tri + Pagy (numérique compact).
   • Cartes : responsive grid, hover → CTA “Ajouter au menu” (si contexte), ⭐ toggle.
   • Aperçu : modal avec photo + 3–5 ingrédients pour les default_servings + bouton “Voir la fiche”.

---

8. TDD — Scénarios (Gherkin)
   Feature: Catalogue & recherche de recettes

Background:
Given des recettes avec diets, tags, temps, et ingrédients variés
And certaines sont "de saison" pour le mois courant
And un utilisateur connecté

Scenario: Chercher par texte et filtrer par régime
When je saisis "poulet" et coche "omnivore"
Then la liste n’affiche que des recettes omnivores contenant "poulet" (nom/tags/ingrédients)

Scenario: Mettre en avant la saison
When j’active "Mettre en avant la saison"
Then les recettes de saison apparaissent en premier
And les hors saison restent visibles

Scenario: Limiter par temps total
When je filtre "Temps total <= 30 min"
Then seules des recettes <= 30 min sont listées

Scenario: Inclure un ingrédient et exclure un autre
When j’inclus "tomate" et j’exclus "lait"
Then aucune recette contenant "lait" n’apparait
And toutes affichées utilisent "tomate"

Scenario: Voir uniquement mes favoris
Given j’ai favorisé "Salade grecque"
When j’active "Mes favoris"
Then je vois "Salade grecque" dans les résultats

Scenario: Ajouter au menu depuis la carte
Given j’ai un MenuDraft actif
When je clique "Ajouter au menu" sur "Salade grecque"
Then la recette est ajoutée au draft (sans doublon)
And je vois un toast "Ajouté au menu"

Scenario: Aperçu rapide
When je clique "Aperçu"
Then une modal affiche la photo, les tags et quelques ingrédients
And je peux cliquer "Voir la fiche recette"

---

9. Specs (exemples RSpec)
   • Query objects / scopes
   o Recipe.seasonal_for(month)
   o Recipe.with_ingredient_names(%w[tomate courgette])
   o Recipe.without_ingredient_names(%w[lait gluten])
   o Recipe.for_diet(diet)
   o Recipe.with_total_time_lte(minutes)
   o Recipe.order_by_seasonal_priority_then(sort)
   • Controller/Feature
   o rend la page avec Pagy, applique les filtres, conserve les chips actifs.
   • Service “AddToDraft” (déjà en UC1/2) : empêche doublon, retourne “added?/message”.

---

10. Modèle & Index (perfs)
    • recipes :
    o index sur diet, prep_time_minutes, cook_time_minutes
    o (option) total_time_minutes materialized + index.
    • ingredients :
    o index name, GIN sur aliases (jsonb).
    • preparations :
    o index (recipe_id, ingredient_id).
    • recipe_tags :
    o index tag_id, (recipe_id, tag_id) unique.
    • favorite_recipes :
    o unique (user_id, recipe_id).
    • Scope saison performant\*\* : EXISTS sur join ingredients where month ∈ season_months.

---

11. Routing / contrôleurs
    GET /recipes -> RecipesController#index
    GET /recipes/:id -> RecipesController#show (UC4)
    POST /recipes/:id/add_to_draft -> Menus::DraftController#add_manual # si draft
    POST /menus/:menu_id/add_recipe -> Menus::MenusController#add_meal_manual # si persisté

# Favori (déjà UC4)

POST /recipes/:id/favorite
DELETE /recipes/:id/favorite

---

12. Sécurité & rôles
    • Lecture : public (ou user only selon ton choix).
    • Ajout au menu/draft : user connecté & propriétaire du contexte.
    • Aucune création d’ingrédient ici (respecte UC3 : réservé admin via pop-up liste).

---

13. Checklist PO/QA
    • Recherche texte + filtres combinables (diet, temps, tags, inclure/exclure ingrédients).
    • “Mettre en avant la saison” réordonne sans exclure.
    • Tri fonctionne (alpha, temps, popularité, saison+popularité).
    • Pagination Pagy stable (conserve filtres dans l’URL).
    • Cartes : infos clés + actions ⭐ + “Ajouter au menu” (si contexte).
    • Aperçu modal OK.
    • “Ajouter au menu” empêche doublon (toast explicite).
    • Indices DB présents (perfs).

---

14. Notes pédagogiques
    • Commence simple : Ransack pour 80% des besoins ; les 20% restants (include/exclude ingrédients, saison boost) via scopes chainables.
    • URLs partageables : garde tous les filtres dans la query string (q[...], only_favorites, etc.).
    • Pagy : super léger, facile à tester.
    • Performance : évite les N+1 (eager-load photo_attachment, tags, preparations.ingredient).
    • UX : garde l’état des filtres, affiche chips amovibles, mets une option “Réinitialiser” claire.
