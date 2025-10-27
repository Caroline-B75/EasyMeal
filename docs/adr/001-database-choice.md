# ADR 001 — Database choice

## Status

Accepted (2025-09-17)

## Context

EasyMeal doit stocker des entités fortement reliées entre elles :

- `User` (avec préférences alimentaires),
- `Recipe` ↔ `Preparation` ↔ `Ingredient`,
- `Menu` ↔ `MenuRecipe` ↔ `GroceryItem`,
- autres entités (Review, FavoriteRecipe, Tags, etc.).

Les cas d’usage principaux exigent :

- **Intégrité relationnelle forte** (ex. pas de recette sans ingrédients, pas de menu_recipes en doublon),
- **Contraintes SQL** (unicité, not null, clés étrangères),
- **Agrégations** (liste de courses : sum des quantités, group by rayon),
- **Recherche** (Ransack, filtres multi-champs, tri),
- **Transactions** fiables (ex. enregistrer un menu + régénérer la liste).

## Options considered

1. **MongoDB (NoSQL)**

   - ✅ Flexible, pas de migrations complexes.
   - ❌ Pas naturel pour les jointures (recettes ↔ ingrédients ↔ menus).
   - ❌ Pas d’intégrité relationnelle garantie par le moteur.
   - ❌ Moins compatible avec les gems Rails courantes (ActiveRecord, Ransack).

2. **PostgreSQL (SQL)**
   - ✅ Excellent support Rails/ActiveRecord.
   - ✅ Contraintes relationnelles (FK, unique, not null).
   - ✅ Support JSON/Array natif si besoin (aliases[], season_months[]).
   - ✅ Compatible avec Ransack, Pagy, scopes SQL avancés.
   - ✅ Large communauté, support long terme.
   - ❌ Moins flexible qu’un NoSQL si schéma instable (mais notre domaine est stable).

## Decision

Nous choisissons **PostgreSQL** comme base de données principale pour EasyMeal.

ActiveRecord sera utilisé comme ORM. Les relations seront fortement typées avec contraintes en base (FK, unique, not null).  
Postgres sera utilisé dans **tous les environnements** (dev, test, prod) pour éviter les incohérences.

## Consequences

- Nous profitons de toute la puissance ActiveRecord, Ransack, Pagy, et des migrations Rails.
- Les contraintes en base nous protègent des doublons (ex. `(menu_id, recipe_id)` unique).
- Les unités/conversions/agrégations (UC3) seront implémentées en Ruby (services), pas en SQL pur → mais Postgres reste performant pour `group by / sum`.
- Les arrays JSONB (aliases, season_months) pourront être indexés via GIN si nécessaire.
