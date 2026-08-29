# Autorisations des utilisateurs

Ce document resume les droits applicatifs actuels a partir des policies Pundit et des controles presents dans les controleurs.

## Roles

| Role                 | Description                                                                                                                                 |
| -------------------- | ------------------------------------------------------------------------------------------------------------------------------------------- |
| Visiteur             | Personne non connectee. Peut consulter les contenus publics.                                                                                |
| Utilisateur connecte | Compte standard authentifie. Peut gerer ses propres donnees et interagir avec les recettes publiees.                                        |
| Admin                | Utilisateur avec `admin: true`. Dispose aussi des droits d'un utilisateur connecte, plus les droits de gestion du catalogue et des comptes. |

## Synthese par ressource

| Ressource / fonctionnalite                              | Visiteur | Utilisateur connecte         | Admin                        | Regle appliquee                                                             |
| ------------------------------------------------------- | -------- | ---------------------------- | ---------------------------- | --------------------------------------------------------------------------- |
| Accueil                                                 | Oui      | Oui                          | Oui                          | Page publique, puis dashboard personnalise si connecte.                     |
| Catalogue des recettes publiees                         | Oui      | Oui                          | Oui                          | `RecipePolicy#index?` et `show?` sont publics.                              |
| Voir une fiche recette publiee                          | Oui      | Oui                          | Oui                          | Lecture publique des recettes publiees.                                     |
| Ajouter / retirer une recette en favori                 | Non      | Oui                          | Oui                          | Recette publiee + utilisateur connecte.                                     |
| Ajouter / retirer une recette dans un brouillon de menu | Non      | Oui                          | Oui                          | Recette publiee + utilisateur connecte.                                     |
| Creer un avis sur une recette                           | Non      | Oui                          | Oui                          | Authentification requise par `Recipes::ReviewsController`.                  |
| Supprimer son propre avis                               | Non      | Oui                          | Oui                          | Suppression limitee a l'avis du `current_user`.                             |
| Voir la liste des ingredients                           | Oui      | Oui                          | Oui                          | `IngredientPolicy#index?` est public.                                       |
| Voir un ingredient                                      | Oui      | Oui                          | Oui                          | `IngredientPolicy#show?` est public.                                        |
| Creer un ingredient                                     | Non      | Non                          | Oui                          | Reserve aux admins.                                                         |
| Modifier un ingredient                                  | Non      | Non                          | Oui                          | Reserve aux admins.                                                         |
| Supprimer un ingredient                                 | Non      | Non                          | Oui                          | Reserve aux admins.                                                         |
| Voir ses menus                                          | Non      | Oui, uniquement les siens    | Oui, uniquement les siens    | `MenuPolicy::Scope` filtre par `user`.                                      |
| Creer un menu                                           | Non      | Oui                          | Oui                          | Tout utilisateur connecte.                                                  |
| Voir un menu                                            | Non      | Oui, si proprietaire         | Oui, si proprietaire         | `MenuPolicy#owner?`.                                                        |
| Modifier un menu                                        | Non      | Oui, si proprietaire         | Oui, si proprietaire         | `MenuPolicy#owner?`.                                                        |
| Supprimer un menu                                       | Non      | Oui, si proprietaire         | Oui, si proprietaire         | `MenuPolicy#owner?`.                                                        |
| Activer / reactiver / repasser un menu en brouillon     | Non      | Oui, si proprietaire         | Oui, si proprietaire         | Actions membres de `MenuPolicy`, basees sur `owner?`.                       |
| Ajouter / remplacer / regenerer des repas d'un menu     | Non      | Oui, si proprietaire         | Oui, si proprietaire         | Actions menu ou `MenuRecipePolicy`, basees sur le menu parent.              |
| Reordonner les repas d'un menu                          | Non      | Oui, si proprietaire         | Oui, si proprietaire         | Controleur autorise via `MenuPolicy#update?`.                               |
| Voir la liste de courses d'un menu                      | Non      | Oui, si proprietaire         | Oui, si proprietaire         | `MenuPolicy#grocery?`.                                                      |
| Ajouter / modifier / supprimer une ligne de courses     | Non      | Oui, si proprietaire du menu | Oui, si proprietaire du menu | `GroceryItemPolicy` verifie le menu parent.                                 |
| Modifier ses preferences de foyer                       | Non      | Oui, ses propres preferences | Oui, ses propres preferences | `ProfilesController` utilise toujours `current_user`.                       |
| Gerer les tags                                          | Non      | Non                          | Oui                          | `TagPolicy` reserve toutes les actions aux admins.                          |
| Creer / modifier / supprimer une recette                | Non      | Non                          | Oui                          | `RecipePolicy#create?`, `update?`, `destroy?`.                              |
| Publier une recette importee par IA                     | Non      | Non                          | Oui                          | `RecipePolicy#publish?`.                                                    |
| Voir / supprimer les brouillons de recettes importees   | Non      | Non                          | Oui                          | `RecipeDraftPolicy`.                                                        |
| Importer une recette par IA                             | Non      | Non                          | Oui                          | `RecipeImportPolicy`.                                                       |
| Gerer les utilisateurs                                  | Non      | Non                          | Oui                          | `UserPolicy` reserve index, edition, mise a jour et suppression aux admins. |

## Details importants

| Sujet                                  | Regle                                                                                                                |
| -------------------------------------- | -------------------------------------------------------------------------------------------------------------------- |
| Admin et donnees personnelles          | Un admin ne voit pas tous les menus par defaut : les scopes de menus restent limites au proprietaire.                |
| Suppression de son propre compte admin | L'interface de gestion bloque la suppression du compte courant.                                                      |
| Auto-retrait des droits admin          | L'interface force `admin: true` sur le compte courant pour eviter qu'un admin se retire accidentellement ses droits. |
| Brouillons de recettes                 | Les recettes non publiees sont gerees via les pages admin dediees, pas dans le catalogue public.                     |
| Favoris et avis                        | Ces actions sont reservees aux utilisateurs connectes et rattachees au compte courant.                               |

## Fichiers de reference

| Domaine              | Fichier                                                                                                        |
| -------------------- | -------------------------------------------------------------------------------------------------------------- |
| Policies globales    | `app/policies/*.rb`                                                                                            |
| Gestion utilisateurs | `app/controllers/users_controller.rb`, `app/policies/user_policy.rb`                                           |
| Menus                | `app/policies/menu_policy.rb`, `app/policies/menu_recipe_policy.rb`                                            |
| Courses              | `app/policies/grocery_item_policy.rb`                                                                          |
| Recettes             | `app/policies/recipe_policy.rb`, `app/policies/recipe_draft_policy.rb`, `app/policies/recipe_import_policy.rb` |
| Ingredients          | `app/policies/ingredient_policy.rb`                                                                            |
| Tags                 | `app/policies/tag_policy.rb`                                                                                   |
