# UC7 — Les types de repas 🥐🍽️🍪🥂🍲

> **Cahier des charges** — issu de la session de conception UX/UI du 08/08/2026.
> Objectif : que le menu pense comme Caroline, pas comme une base de données.

---

## 🎬 L'histoire

Aujourd'hui, EasyMeal génère « 12 repas ». Mais 12 repas de *quoi* ?

Dans la vraie vie, une semaine ne se compte pas en repas anonymes. Elle se compte comme ça :

| 🥐 Petits-déjeuners | 🍽️ Déjeuners | 🍪 Goûters | 🥂 Apéros | 🍲 Dîners |
|:---:|:---:|:---:|:---:|:---:|
| 7 | 2 | 7 | 1 | 7 |

*(Exemple d'une famille de 4 qui cuisine matin et soir en semaine, et matin-midi-soir le week-end.)*

**La grande idée de cette évolution** : on décrit sa semaine *avant* de générer, et le menu se compose tout seul pour y répondre. Fini le tas de recettes à trier mentalement — chaque recette arrive déjà à sa place.

---

## 📖 Chapitre 1 — Chaque recette annonce son moment

**Ce qui change** : la fiche recette gagne un champ obligatoire **« Moment(s) du repas »**, présenté en chips à cocher :

`[ 🥐 Petit-déj ] [ 🍽️ Déjeuner ] [ 🍪 Goûter ] [ 🥂 Apéro ] [ 🍲 Dîner ]`

**Règle d'or : une recette peut cocher PLUSIEURS cases.** Une quiche vit au déjeuner *et* au dîner. Des pancakes brillent au petit-déj *et* au goûter. Un cake salé fait le dîner *et* l'apéro. Forcer un choix unique appauvrirait les tirages — on ne le fait pas.

**Côté technique** :
- Colonne array PostgreSQL `recipes.meal_types` (même idiome que `ingredients.season_months`).
- Validation : au moins une valeur cochée… **sauf** pour les brouillons importés par IA (même exemption que la règle « au moins un ingrédient »).
- Migration de l'existant : toutes les recettes actuelles sont backfillées en `["lunch", "dinner"]` (ce sont des plats, dans leur écrasante majorité). On affine ensuite à la main.
- `MenuRecipe.meal_type` et ses scopes existent déjà en base — ils attendaient ce moment. ✨ On ajoute simplement `"apero"` aux `MEAL_TYPES`, et on supprime la colonne `scheduled_date` jamais branchée (chasse au code mort).

**Complexité : 🟢 simple à moyenne**

---

## 📖 Chapitre 2 — On passe commande de sa semaine

**Ce qui change** : dans le formulaire de génération, le slider unique « Nombre de repas » est remplacé par **5 petits steppers**, un par moment :

```
🥐 Petits-déjeuners   [ − ] 7 [ + ]
🍽️ Déjeuners          [ − ] 2 [ + ]
🍪 Goûters            [ − ] 7 [ + ]
🥂 Apéros             [ − ] 1 [ + ]
🍲 Dîners             [ − ] 7 [ + ]
```

**Valeurs par défaut au premier passage** : tous les steppers démarrent à **0**, sauf 🍽️ Déjeuners et 🍲 Dîners. On n'active que ce qu'on cuisine vraiment.

**La condition pour que ça reste un jeu d'enfant** : la case « Mémoriser ces paramètres » (déjà existante) mémorise désormais **toute la répartition**. On décrit sa semaine type *une seule fois* ; ensuite, générer un menu redevient un clic.

**Côté technique** : la préférence utilisateur `default_number_of_meals` est remplacée par une répartition par type. La barre de résumé en temps réel du formulaire s'adapte (« 7 petits-déjs · 2 déjs · 7 goûters · 1 apéro · 7 dîners »).

**Complexité : 🟡 moyenne**

---

## 📖 Chapitre 3 — La génération honore la commande

**Ce qui change** : le moteur de génération pioche **par quotas** : 7 recettes taguées petit-déj, 2 déjeuners, etc. La priorité aux recettes **de saison** est conservée à l'intérieur de chaque quota.

**Deux règles nouvelles, pleines de bon sens :**

1. **🍞 La répétition est permise.** Dans la vraie vie, le petit-déjeuner est souvent le même tous les jours ! La contrainte « une recette ne peut apparaître qu'une fois par menu » est levée (suppression de l'index unique `menu_id + recipe_id`). Et à la génération, une option **« Mon petit-déjeuner est le même toute la semaine »** pioche 1 recette et la place 7 fois. Une seule brioche, sept matins heureux.

2. **🕳️ Un pool trop maigre n'est pas un échec.** Si le catalogue n'a que 4 recettes de petit-déj pour 7 demandées, on remplit ce qu'on peut et le brouillon l'affiche clairement :
   > *« Il manque 3 petits-déjeuners — ajoute-les depuis le catalogue ! »*
   
   La limite devient une invitation à enrichir le catalogue, jamais un message d'erreur.

**Côté technique** : boucle type → quantité dans `Menus::GenerateService`, paramètre `meal_type` dans `Menus::CandidatePickerService`. Les quotas demandés sont **mémorisés sur le menu** (colonne `requested_meal_counts`, jsonb) : c'est ce qui permet d'afficher « Il manque X … » dans le brouillon et de re-générer avec la même commande. Extension propre, pas de refonte. Vérifier l'impact de la levée d'unicité sur la génération de la liste de courses.

**Complexité : 🟡 moyenne**

---

## 📖 Chapitre 4 — Un brouillon rangé par moments

**Ce qui change** : la grille du brouillon se regroupe en **sections** :

```
── 🥐 Petits-déjeuners (7) ──────────────
   [carte] [carte] [carte] …  [+ catalogue]

── 🍽️ Déjeuners (2) ─────────────────────
   [carte] [carte]            [+ catalogue]

── 🍲 Dîners (7) ────────────────────────
   [carte] [carte] [carte] …  [+ catalogue]
```

**Décision d'équipe** ✅ : après la génération, on n'ajoute **que depuis le catalogue**. La magie de l'aléatoire a déjà opéré à la génération — pour compléter après coup, on choisit en conscience. Le bouton « Repas aléatoire » du brouillon disparaît, le code et l'UX s'en trouvent simplifiés.

- Chaque section porte son bouton **« + catalogue »** qui ouvre le catalogue **pré-filtré sur le bon moment**. L'utilisateur n'a jamais à préciser le type : il ajoute *dans* la section, le contexte fait le travail.
- Le bouton 🔀 de **remplacement** sur chaque carte est conservé (il tire désormais dans le pool du bon type).
- Le message « Il manque X … » (chapitre 3) s'affiche en tête de section incomplète — il remplace avantageusement toute jauge de complétude.

**Les cartes de repas s'enrichissent aussi :**

- ⏱️ **Badge temps de préparation** : le temps total (préparation + cuisson, déjà porté par `Recipe#total_time_minutes`) s'affiche sur chaque carte. C'est LE critère pour décider ce qu'on cuisine un mardi soir vs un dimanche midi.
- 🏷️ **Sélecteur de type de repas** : un dropdown « Petit-déj / Déjeuner / Goûter / Apéro / Dîner » sur la carte, avec la même mécanique `auto-submit` que le sélecteur de personnes. Le changer **déplace la carte vers sa nouvelle section** — pratique pour requalifier un repas sans le supprimer/recréer.
- 📱 **Réorganisation au doigt** : le drag & drop HTML5 ne fonctionne pas au tactile. Sur mobile, des boutons discrets « ⬆️ monter / ⬇️ descendre » permettent de réordonner les cartes *à l'intérieur de leur section*.
- 📅 **Jour de la semaine (optionnel)** : un dropdown « Jour » (— / Lundi / … / Dimanche) sur la carte, même mécanique auto-submit, vide par défaut, avec un badge discret quand le jour est renseigné. **Aucune logique de tri, de groupement ou de validation** : la position manuelle reste la seule vérité d'ordre — le badge *annote* la chronologie que l'utilisateur construit lui-même en réordonnant ses cartes. C'est ce « rien » qui rend la fonctionnalité simple, triviale à maintenir, sans effet de bord… et compatible avec les menus de plus de 7 jours (les deux lundis ne seront jamais regroupés de force). Colonne `menu_recipes.day_of_week` (integer 0–6, nullable) — la brique de données de la future vue semaine.

**Complexité : 🟡 moyenne** (regroupement de la grille, suppression de code, filtre pré-appliqué, enrichissement des cartes)

---

## 📖 Chapitre 5 — Le catalogue filtre par moment

**Ce qui change** : un filtre **« Moment du repas »** rejoint les filtres existants du catalogue (régime, difficulté, temps…). Il sert à la navigation libre, et c'est lui qui est pré-appliqué par les boutons « + catalogue » des sections.

**Côté technique** : un scope de plus dans `Recipes::FilterService`, qui empile déjà ce genre de filtres.

**Complexité : 🟢 simple**

---

## ⚠️ Le prérequis avant de coder : l'état des lieux du catalogue

La fonctionnalité ne vaudra que ce que valent les pools. Avant de démarrer :

- [ ] Compter les recettes qui pourront être taguées 🥐 petit-déj, 🍪 goûter, 🥂 apéro.
- [ ] Si un pool est quasi vide, prévoir une fournée de recettes (l'import IA est là pour ça).

---

## 🗓️ Pour plus tard (hors périmètre de ce chantier)

Idées discutées et gardées au chaud, volontairement **exclues** de cette version :

- **La vue semaine** (placer les repas par jour : Lundi / Mardi / …) — les quotas préparent naturellement le terrain ; le placement par jour viendra comme une couche optionnelle par-dessus, en mode « remplir les cases » plutôt qu'en drag & drop.
- **Le drag & drop tactile** entre cases — coûteux à développer et à maintenir sur mobile, on ne s'y enferme pas.
- **Exclusion des recettes des derniers menus** dans les tirages aléatoires, pour varier les plaisirs d'une semaine à l'autre.
- **Bouton « Ranger par jour »** : une action ponctuelle (jamais un tri imposé) qui réécrirait les positions selon les jours renseignés, en préservant l'ordre relatif des cartes d'un même jour — puis rendrait la main au réordonnancement manuel. À n'envisager que si l'usage le réclame.

---

## 🧮 Récapitulatif des complexités

| Chantier | Complexité |
|---|:---:|
| Champ `meal_types` multi + migration + backfill | 🟢 simple à moyenne |
| Formulaire de génération à 5 steppers + mémorisation | 🟡 moyenne |
| Génération par quotas + répétition + remplissage partiel | 🟡 moyenne |
| Brouillon en sections + ajout catalogue contextualisé | 🟡 moyenne |
| Filtre catalogue par moment | 🟢 simple |

**Verdict global : un chantier de complexité moyenne, sans refonte structurelle.** Le modèle de données était déjà à moitié prêt — il ne demandait qu'à servir. 🚀
