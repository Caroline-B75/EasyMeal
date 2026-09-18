# UC8 — Étape 3 : les courses habituelles ↺

> **Cahier des charges** — issu de la session de conception du 17/09/2026.
> **Livré le 18/09/2026** : voir « Ce qui a changé en cours de route » en fin de document.
> Suite du foyer partagé ([UC8_foyer_partage.md](UC8_foyer_partage.md)).
> Objectif : ne plus ressaisir chaque semaine, article par article, ce que le
> foyer achète de toute façon.

---

## 🎬 L'histoire

Aujourd'hui, pour acheter du dentifrice, du papier toilette ou le lait de la
semaine, on passe par le petit formulaire « Ajouter un article » en bas de la
liste de courses. Un article à la fois, toutes les semaines.

**La grande idée** : le foyer enregistre une fois pour toutes sa liste de
**courses habituelles**. Chaque semaine, un bouton **« Mes habituelles »** l'ouvre
dans une pop-up : on décoche ce dont on n'a pas besoin cette fois, on ajuste une
quantité, et tout rejoint la liste de courses, chaque article dans son rayon.

---

## ✅ Décisions prises

| Question | Décision |
|---|---|
| Nom | « Courses habituelles » ; le bouton s'appelle « Mes habituelles » (d'abord « Mes habituels », accordé à « courses » le 18/09) |
| Combien de listes ? | **Une seule par foyer**, partagée par tous ses membres |
| Écarter un article pour cette semaine | On le **décoche** dans la pop-up (on ne supprime rien) |
| Changer une quantité pour cette semaine | **Dans la pop-up**, et pour cette fois seulement |
| Article déjà dans la liste (le lait du menu) | Les quantités **s'additionnent** sur une seule ligne |
| Marque visuelle | **Une seule** : ↺ pour ce qui vient des habituels ; rien pour le menu ni pour les ajouts ponctuels |
| Plusieurs membres en même temps | Cas non visé : on part du principe qu'ils ne gèrent pas la liste au même moment |

---

## 📖 Chapitre 1 — La liste des courses habituelles

**Ce qui change** : une page **« Courses habituelles »** (`/foyer/courses-habituelles`),
accessible depuis « Mon foyer » et depuis la pop-up (lien « Modifier ma liste »).

- On y ajoute un article avec **le même formulaire** que sur la liste de courses :
  suggestions du catalogue, quantité, unité, rayon. Un article reconnu impose son
  rayon et ses unités, exactement comme aujourd'hui.
- Les articles s'affichent groupés par rayon, dans l'ordre de la liste de courses.
- Sur chaque ligne : modifier la quantité et l'unité, ou supprimer l'article.
  Pour changer d'article, on le supprime et on en ajoute un autre.
- Un même article ne peut figurer qu'une fois dans la liste (même ingrédient, ou
  même nom aux accents et à la casse près) : « Lait est déjà dans tes courses
  habituelles ».
- Tous les membres du foyer voient et modifient la même liste.

**Côté technique** :
- Nouveau modèle `UsualGroceryItem` (table `usual_grocery_items`) :
  `household_id` (obligatoire), `ingredient_id` (facultatif), `name`, `quantity`
  (decimal), `unit` (unité canonique de `Units`), `category`, timestamps.
- **On garde ce qui a été saisi, pas le résultat** : « 6 L » reste « 6 L ». La
  conversion vers l'unité de base se fait au moment de l'ajout à la liste de
  courses (chapitre 3). Si l'admin change le rayon d'un ingrédient, les
  habituels suivent.
- `category` est enregistré même pour un article reconnu : c'est le rayon de
  repli si l'ingrédient disparaît du catalogue.
- Validations : nom présent, quantité > 0, unité canonique, rayon connu, unicité
  dans le foyer. Pour un article reconnu : l'unité doit pouvoir se convertir pour
  cet ingrédient (même contrôle que `AddManualItemService#unconvertible_result`).
- **Reconnaissance d'un ingrédient mise en commun** : la recherche « id posé par
  l'autocomplétion, sinon nom, sinon alias » sort de `AddManualItemService` vers
  une méthode d'`Ingredient` (ex. `Ingredient.recognize(name:, id:)`), utilisée
  par le service et par `UsualGroceryItem`.
- **Correspondance entre articles mise en commun** : la règle « même ingrédient,
  sinon même nom aux accents et à la casse près » (`GroceryItem.matching_article`)
  sert aussi à l'unicité des habituels et au repérage des articles « déjà ajoutés »
  (chapitre 2). À extraire dans un concern partagé plutôt que la recopier.
- **Table des rayons** : `GroceryItem` recopie déjà celle d'`Ingredient`. Une
  troisième copie est exclue : une constante partagée par les trois modèles.
- Associations : `Household has_many :usual_grocery_items, dependent: :destroy` ;
  `Ingredient has_many :usual_grocery_items, dependent: :nullify`.
- Contrôleur `Households::UsualGroceryItemsController` (`index`, `create`,
  `update`, `destroy`), route imbriquée sous `resource :household`. Les articles
  sont toujours cherchés dans `current_user.household.usual_grocery_items`, ce
  qui tient lieu d'autorisation (même principe que `HouseholdsController`).
- Le formulaire d'ajout de `menus/grocery.html.haml` devient un partial commun aux
  deux pages (URL passée en local), avec le même contrôleur Stimulus
  `ingredient-combobox`.
- « Mon foyer » gagne une section « Courses habituelles » : le nombre d'articles
  et un lien vers la page.

**Complexité : 🟢 simple à moyenne**

---

## 📖 Chapitre 2 — La pop-up « Mes habituelles »

**Ce qui change** : un bouton secondaire **« Mes habituelles »** (icône ↺), à côté du
titre « Ajouter un article », en bas de la liste de courses. Il ouvre une pop-up :

```
┌─ Mes habituelles ─────────────────────────────┐
│ ☑ Lait                        [ 6   ] L       │
│ ☑ Papier toilette             [ 1   ] paquet  │
│ ☐ Dentifrice                  [ 1   ]         │
│ ☐ Café                        [ 2   ] paquets │
│     déjà ajouté                                │
│                                                │
│ Modifier ma liste     [Annuler] [Ajouter 2 articles] │
└────────────────────────────────────────────────┘
```

- Les articles sont **cochés au départ** et triés comme la liste de courses.
- **Décocher** = pas cette semaine. Rien n'est supprimé de la liste habituelle.
- **La quantité se modifie dans la pop-up**, pour cette fois seulement. La
  quantité habituelle, elle, se change sur la page du chapitre 1.
- **« Déjà ajouté »** : un article dont la ligne de courses contient déjà une part
  habituelle arrive **décoché**, avec cette mention. On évite ainsi d'ajouter deux
  fois les habituels (12 L de lait). On peut le recocher volontairement.
- Le bouton principal indique le nombre d'articles : « Ajouter 11 articles ». Il
  est désactivé à 0.
- Après l'ajout, la pop-up se ferme, la liste se met à jour et un bandeau résume :
  « 11 articles ajoutés, dont 2 additionnés à une ligne existante ». Un article qui
  n'a pas pu être ajouté est nommé dans le bandeau, avec la raison.
- **Liste habituelle vide** : la pop-up le dit et propose deux chemins :
  « Créer ma liste » (lien vers la page), et, si la liste de courses en contient,
  **« Reprendre les N articles ajoutés à la main »**. Ce sont justement ceux qu'on
  ressaisit chaque semaine. On arrive ensuite sur la page de la liste pour la
  vérifier.
- La pop-up ouverte **ne se ferme pas et ne perd rien** (décochages, quantités)
  si la page se rafraîchit en direct, par exemple quand le téléphone sort de veille.

**Côté technique** :
- Élément natif `<dialog>` ouvert par `showModal()` (focus piégé, Échap, fond),
  habillé des classes `.modal-*` existantes, et boutons canoniques `.btn`.
  Nouveau contrôleur Stimulus `usual-groceries` : ouverture, fermeture, compteur
  du bouton, fermeture sur `turbo:submit-end` réussi.
- Le contenu de la pop-up est un turbo-frame **rechargé à chaque ouverture**
  (`GET /menus/:menu_id/grocery_items/usual`) : il est toujours à jour, sans
  peser sur chaque rafraîchissement de la liste. Le `<dialog>` porte
  `data-turbo-permanent` : un rafraîchissement en direct ne le touche pas.
- Le formulaire envoie, par article, la case et la quantité. Le serveur ne retient
  que les articles cochés dont la quantité est > 0, et les cherche dans
  `menu.household.usual_grocery_items` : un id d'un autre foyer est ignoré.
- Route : `POST /menus/:menu_id/grocery_items/usual` (collection, à côté de
  `claim_section`), autorisée par `GroceryItemPolicy#create?`. Mêmes droits que
  l'ajout manuel, sans contrôle de statut supplémentaire : la page qui porte le
  bouton n'existe que pour un menu actif ou en attente de revalidation.
- Réponse : redirection vers la liste de courses avec le bandeau, rendue en morph
  comme le reste de la page.
- « Reprendre les articles ajoutés à la main » : action de collection
  sur `Households::UsualGroceryItemsController` (`menu_id` en paramètre), qui
  crée un habituel par ligne ponctuelle du menu (ligne `manual` sans part
  habituelle), en ignorant les articles déjà présents. La quantité est reprise
  dans l'unité la plus lisible (« 2 kg » plutôt que « 2000 g », via
  `Quantities::HumanizeService`), sinon dans l'unité de base.

**Complexité : 🟡 moyenne**

---

## 📖 Chapitre 3 — Les quantités s'additionnent

**Ce qui change** : si un article habituel est déjà dans la liste de courses, sa
quantité **s'ajoute** à la ligne existante au lieu de créer un doublon.

```
☐  Lait                         6,05 L
   ↺ dont 6 L de tes habituelles
```

**Les règles**, toutes tirées d'un seul principe : **une ligne = sa part (menu ou
ajout ponctuel) + sa part habituelle**. La part du menu est recalculée à chaque
validation ; la part habituelle est conservée.

1. **Ajout** : le total augmente, et la ligne retient la part habituelle.
2. **Aucune ligne existante** : une nouvelle ligne est créée, entièrement habituelle.
3. **Ligne déjà cochée qui augmente** : elle se décoche et affiche le badge
   « Tu en as peut-être déjà acheté 50 cl… » — même règle que lors d'une
   modification du menu.
4. **Revalidation du menu** : total = quantité du menu recalculée + part habituelle.
   Les 6 L ne se perdent jamais.
5. **Le menu n'a plus besoin de l'article** : la ligne ne disparaît pas, elle garde
   ses 6 L et devient une ligne habituelle (supprimable).
6. **Le menu a désormais besoin d'un article ajouté seulement par les habituels** :
   la ligne habituelle rejoint le menu (6 L + 50 cl sur une seule ligne) plutôt que
   de laisser le menu créer une seconde ligne « Lait ».
7. **Quantité corrigée à la main sur une ligne qui a une part habituelle** : la
   correction porte sur la part habituelle ; la part du menu (ou ponctuelle) ne
   bouge pas. Si la correction descend sous cette part, la part habituelle
   disparaît.
8. **Unités qui ne s'additionnent pas** (un article libre en paquets face à une
   ligne en grammes) : l'article habituel prend une ligne à part. Cas rare.
9. **Menu archivé réactivé** : sa liste repart « fraîche » comme aujourd'hui ; les
   parts habituelles sont retirées (une ligne entièrement habituelle disparaît).
   On rajoute les habituels d'un clic.

L'ajout manuel ponctuel ne change pas : un article déjà présent est toujours
refusé, avec le message qui renvoie vers la ligne existante.

**Côté technique** :
- Migration : `grocery_items.usual_quantity_base` (decimal 10,3, nullable). Nul =
  aucune part habituelle ; sinon `0 < usual_quantity_base ≤ quantity_base`. Pas de
  nouvelle valeur pour l'enum `source` : une ligne entièrement habituelle est une
  ligne `manual` dont la part habituelle vaut le total.
- `Groceries::AddManualItemService` apprend un mode `usual: true`. La
  reconnaissance, le rayon et la conversion restent communs ; seule change l'issue
  d'un doublon : addition (`:merged`) au lieu du refus (`:duplicate`), ou ligne
  à part si les unités de base diffèrent (règle 8).
- Nouveau `Groceries::AddUsualItemsService` : pour les articles retenus, appelle le
  service ci-dessus dans une transaction et renvoie le bilan (ajoutés, additionnés,
  refusés et pourquoi) qui alimente le bandeau.
- **Règle 3 mise en commun** : « hausse sur une ligne cochée → décoche + ancienne
  quantité mémorisée » sort de `BuildForMenuService#update_grocery_item` vers une
  méthode de `GroceryItem`, appelée par la réconciliation et par l'addition.
- **Texte du badge** : il dit aujourd'hui « avant la modification du menu ». Il
  devient neutre, puisque la hausse peut venir des habituels : « Tu en as peut-être
  déjà acheté 50 cl avant que la quantité augmente. »
- `Groceries::BuildForMenuService` :
  - `update_grocery_item` : nouvelle quantité = agrégat du menu + part habituelle ;
  - lignes générées que le menu ne demande plus : détruites seulement sans part
    habituelle, sinon repassées en `manual` avec quantité = part habituelle (règle 5) ;
  - avant de créer une ligne générée : adopter la ligne `manual` du même ingrédient
    qui est entièrement habituelle (règle 6). Une ligne ponctuelle n'est jamais
    adoptée, comme aujourd'hui ;
  - l'idempotence est conservée.
- Règle 7 : méthode de `GroceryItem` appelée explicitement par
  `GroceryItemsController#update`, comme `assign_buyer`. **Pas un callback** : la
  réconciliation modifie aussi `quantity_base` et ne doit pas toucher à la part
  habituelle.
- Règle 9 : `Menu#reactivate!` retire les parts habituelles avant `activate!`.

**Complexité : 🔴 délicate** — c'est la réconciliation qui préserve les coches.
Elle est bien couverte par les tests ; chaque règle ci-dessus y gagne son exemple.

---

## 📖 Chapitre 4 — La marque ↺

**Ce qui change** :
- Une ligne **entièrement habituelle** : petite icône ↺ grisée après le nom.
- Une ligne **qui cumule** menu (ou ajout ponctuel) et habituels : sous le nom, en
  petit et grisé, « ↺ dont 6 L de tes habituelles ».
- Les lignes du menu et les ajouts ponctuels ne portent **aucune marque** : c'est
  le cas normal, et une marque présente partout ne se lit plus.
- Les modes Courses et Répartir, et le filtre « Ma part », ne changent pas.

**Côté technique** :
- Icône `rotate-ccw` du jeu existant (`svg_icon`), décorative. Le sens est porté
  par un texte pour les lecteurs d'écran : « Course habituelle ».
- `GroceryItem#usual_quantity_display` s'appuie sur `format_quantity`, comme
  `previous_quantity_display`.
- Classes dans `grocery_items.css`, couleurs par variables `var(--color-*)`. À
  vérifier sur mobile avec une ligne chargée (pseudo de qui s'en occupe, badge,
  quantité, croix).

**Complexité : 🟢 simple**

---

## 👥 Le foyer

- **Quitter le foyer, ou en être retiré** : la liste habituelle reste au foyer ; on
  repart avec une liste vide.
- **Rejoindre un foyer en étant seul dans le sien** : ses habituels **rejoignent**
  la liste du nouveau foyer, sauf les articles qui y figurent déjà (dans
  `Household#admit!`, avant que l'ancien foyer ne soit détruit).
- **Supprimer le dernier compte d'un foyer** : la liste disparaît avec le foyer.
- La section « Le foyer (UC8) » de `CLAUDE.md` gagne un paragraphe sur les
  courses habituelles une fois la fonctionnalité livrée.

---

## 🧪 Vérifications prévues

- **Mesurer la suite RSpec avant de coder** : toute différence ensuite est une
  régression.
- Specs de modèle : `UsualGroceryItem` (validations, unicité, rayon de repli),
  règles 3 et 7 sur `GroceryItem`, fusion des listes dans `Household#admit!`.
- Specs de service : `AddManualItemService` en mode habituel (création, addition,
  ligne cochée, unités incompatibles) ; `AddUsualItemsService` (bilan, ids d'un
  autre foyer ignorés) ; `BuildForMenuService` (règles 4, 5, 6, idempotence).
- Specs de requête : page des habituels (accès limité au foyer), ajout depuis la
  pop-up, reprise des articles ajoutés à la main, réactivation d'un menu (règle 9).
- RuboCop sans remarque.
- Essai réel dans le navigateur (mobile et ordinateur) : pop-up (décocher,
  quantité, « déjà ajouté », rafraîchissement en direct pendant qu'elle est
  ouverte), marque ↺ et note « dont … de tes habituelles ».

---

## 🗓️ Pour plus tard (hors périmètre)

- **Plusieurs listes par foyer** (« Drive », « Bébé »…).
- **Retenir une quantité modifiée dans la pop-up** comme nouvelle quantité habituelle.
- **Une marque pour les ajouts ponctuels**, ou l'indication de qui a ajouté un article.
- **Deux membres qui gèrent la liste au même moment.**

---

## 🔧 Ce qui a changé en cours de route

- **La note des lignes qui cumulent** dit « dont 6 L **de tes** habituelles » (tes courses habituelles) et non
  « dont 6 L habituels » : l'accord aurait suivi l'unité (« 2 briques habituelles »).
- **La pop-up se recharge à chaque ouverture** au lieu d'être rendue avec la page
  (cf. chapitre 2) : plus simple à protéger des rafraîchissements en direct, et
  sans requête supplémentaire sur la liste tant qu'on ne l'ouvre pas.
- **Les noms dans le code** : `UsualGroceryItem`,
  `usual_quantity_base`, `Groceries::AddUsualItemsService`,
  `UsualGroceryAdditionsController` (la pop-up) et
  `Households::UsualGroceryItemsController` (la page).

## ✔️ Vérifié

- **917 exemples, 0 échec** (844 avant le chantier), RuboCop sans remarque.
- **Essai réel** sur un serveur de développement, avec un compte jetable : pop-up
  (compteur, ligne estompée, quantité de cette fois), rafraîchissement en direct
  pendant qu'elle est ouverte, ajout (lait additionné, marques ↺), réouverture
  (« Déjà ajouté » décoché), page des habituels (correction enregistrée d'elle-même),
  section de « Mon foyer ». Sur mobile (390 px) et sur ordinateur, sans débordement.

---

## 🎨 Refonte visuelle (18/09/2026)

Proposée sur maquettes (canevas « Foyer et habituels — propositions ») puis
validée telle quelle par l'utilisatrice.

- **« Mon foyer »** : bandeau anthracite (registre du tableau de bord de
  l'accueil) avec les avatars des membres qui se chevauchent et une place libre
  « + » ; titre fait des prénoms (« Caroline & Guillaume ») ; puis des cartes —
  membres, courses habituelles (aperçu en pastilles aux couleurs des rayons),
  invitation, « Partagé / Rien qu'à toi ». « Retirer du foyer » passe derrière
  un menu « ⋯ » (`<details>`, sans JavaScript), « Quitter le foyer » en bas de page.
- **Couleurs de membre** : chaque membre a sa couleur d'avatar, selon son rang
  dans le foyer (`HouseholdsHelper#member_color`, palette `.member-avatar` —
  les pastels des jours du menu). L'en-tête de chaque page la reprend.
- **Rappel en tête de la liste de courses** tant que les habituels n'y sont pas
  (`Menu#usual_groceries_pending?`) : il ouvre la même pop-up que le bouton du bas,
  et disparaît de lui-même après l'ajout.
- **Pop-up** : panneau qui monte du bas sur mobile ; pastille de rayon devant
  chaque article ; boutons − / + (par 50 g, 50 ml ou 5 cl selon l'unité,
  `number-stepper` apprend un pas) ; « Tout cocher / Tout décocher » ; la croix
  du haut remplace « Annuler ».
- **Page des habituels** : une carte par rayon coiffée d'un bandeau à ses
  couleurs, sur deux colonnes ; la quantité se lit dans une pastille qui ouvre
  l'éditeur — dans la ligne sur grand écran, en panneau montant du bas sur
  mobile ; ajout par un seul champ qui ne déplie quantité, unité et rayon qu'à
  la saisie (`grocery-add-form--compact`).
- **Liste de courses** : les rayons prennent le même bandeau coloré, avec leur
  pastille. Sur le beige de la page, il prend l'aplat des contrôles de rayon
  (`--category-tint`) ; sur les cartes blanches des habituels, l'aplat plus
  dilué (`--category-wash`).

Vérifié : 931 exemples, 0 échec ; RuboCop sans remarque ; essai réel à deux
comptes jetables, sur mobile (390 px) et sur ordinateur, sans débordement ni
alerte Bullet.
