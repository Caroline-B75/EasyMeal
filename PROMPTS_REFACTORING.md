# Plan de refactoring EasyMeal — prompts à envoyer un par un

Issu de l'analyse RubyCritic du 11/08/2026 (score 88.77 — 50 A, 14 B, 7 C, 2 D).

## Mode d'emploi

Envoie **un seul prompt à la fois**, dans l'ordre. Chaque prompt est autonome :
copie-colle le bloc « Prompt à envoyer » tel quel.

Après chaque étape :
1. Je relance les RSpec indiqués.
2. Tu fais les vérifications visuelles listées.
3. **Tu commites toi-même** avec le nom proposé (je ne commite jamais).

Rappels d'environnement :
- Ruby/Rails tournent **uniquement dans WSL** (`cd /mnt/c/Caroline/easymeal`).
- Git se fait en **PowerShell**.
- Baseline RSpec : la suite doit rester 100 % verte. Tout échec est une vraie régression.

Ordre voulu : d'abord **mesurer** (étape 1), puis les **gains rapides** (étapes 2 à 8),
puis le **gros chantier** `ExtractorService` (étapes 9 à 12).

---

# Étape 1 — Rendre la couverture de tests mesurable

> Le rapport RubyCritic affiche 0 % de couverture sur les 73 fichiers. Ce n'est pas
> la réalité : SimpleCov n'est simplement pas branché. On corrige ça d'abord, pour
> savoir ce qui est réellement testé avant de toucher au code.

### Prompt à envoyer

- **Modèle conseillé** : Sonnet — effort faible (configuration d'outillage, aucun code applicatif touché)

```
**Qualité non négociable** : code simple, refactorisé, DRY, bien commenté, fiable, robuste, zéro code mort, bonnes pratiques Rails/Hotwire/HAML et conventions du projet.

Contexte : le rapport RubyCritic affiche 0 % de couverture sur tous les fichiers.
En réalité SimpleCov n'est jamais chargé — il n'arrive dans le projet que comme
dépendance transitive de rubycritic (Gemfile.lock), et aucun fichier de spec ne le
require. L'onglet "Coverage" du rapport ne mesure donc rien. Objectif : brancher
SimpleCov pour obtenir une vraie mesure de couverture, sans rien changer au code
applicatif.

Fichiers de contexte :
- spec/rails_helper.rb
- spec/spec_helper.rb
- Gemfile
- .gitignore

Demandes :
1. Ajoute `gem "simplecov", require: false` au groupe :test du Gemfile (il est déjà
   présent en transitif, on le rend explicite).
2. Charge SimpleCov tout en haut de spec/rails_helper.rb, AVANT le
   `require_relative '../config/environment'` — sinon les fichiers déjà chargés ne
   sont pas instrumentés.
3. Configure-le : `add_filter "/spec/"`, `add_filter "/config/"`, et des
   `add_group` pour Models, Controllers, Services, Helpers, Concerns.
4. Ajoute `/coverage/` au .gitignore s'il n'y est pas.
5. Ne modifie AUCUN fichier de app/.
```

### RSpec

À relancer (aucun à modifier) :
```bash
cd /mnt/c/Caroline/easymeal && bundle exec rspec
```
Le nombre d'exemples ne doit pas bouger, et un résumé de couverture doit s'afficher
en fin d'exécution.

### Vérification de ton côté

Rien sur le site. Ouvre `coverage/index.html` depuis l'Explorateur Windows : tu dois
voir un pourcentage réel par fichier. Ensuite `bundle exec rubycritic app` affichera
enfin de vrais chiffres dans l'onglet Coverage.

### Ce que ça fait

SimpleCov est un outil qui note quelles lignes de code ont été exécutées pendant les
tests. Il doit se lancer **avant** l'application, sinon il rate tout ce qui a déjà été
chargé — c'est exactement le bug ici. Une fois branché, tu sauras quelles parties du
projet ne sont couvertes par aucun test, ce qui indique où il est risqué de refactorer.

### Commit proposé

`ajout de SimpleCov pour mesurer la couverture de tests`

---

# Étape 2 — Supprimer le code mort

> CLAUDE.md interdit explicitement le code mort. Deux méthodes ne servent à rien.

### Prompt à envoyer

- **Modèle conseillé** : Sonnet — effort faible (suppression guidée, périmètre déjà identifié)

```
**Qualité non négociable** : code simple, refactorisé, DRY, bien commenté, fiable, robuste, zéro code mort, bonnes pratiques Rails/Hotwire/HAML et conventions du projet.

Contexte : deux méthodes mortes traînent dans le projet, ce que CLAUDE.md interdit
explicitement ("aucune méthode, classe, variable... inutilisée ne doit rester").

1. ApplicationHelper#clean_error_message (privée) retourne son argument inchangé —
   c'est une fonction identité. Elle n'est appelée qu'à un seul endroit, dans
   #field_errors.
2. Ingredient#default_base_unit n'est appelée nulle part dans app/, lib/, spec/,
   db/ ni dans le JavaScript. Seul un commentaire de db/seeds/ingredients.rb la
   mentionne.

Fichiers de contexte :
- app/helpers/application_helper.rb (lignes 73-92 et 208-213)
- app/models/ingredient.rb (lignes 99-117)
- db/seeds/ingredients.rb (le commentaire ligne 12)

Demandes :
1. Supprime clean_error_message et simplifie #field_errors pour utiliser
   directement object.errors[attribute] (le .map devient inutile).
2. Supprime Ingredient#default_base_unit.
3. Corrige le commentaire de db/seeds/ingredients.rb ligne 12 qui référence
   default_base_unit, pour qu'il pointe uniquement sur la validation du modèle.
4. Avant de supprimer, vérifie par grep que ces deux méthodes ne sont réellement
   appelées nulle part (y compris dans les vues .haml et le JS).
```

### RSpec

À relancer :
```bash
cd /mnt/c/Caroline/easymeal && bundle exec rspec spec/helpers spec/models
```
Puis la suite complète pour confirmer.

### Vérification de ton côté

- Ouvre un formulaire de recette et soumets-le **vide** → les messages d'erreur rouges
  sous les champs doivent s'afficher exactement comme avant.
- Va sur `/ingredients/new`, choisis un groupe d'unités → l'unité de base doit toujours
  se remplir automatiquement (c'est le JavaScript qui le fait, pas la méthode supprimée).

### Ce que ça fait

`clean_error_message` était une méthode qui prenait un message et le rendait tel quel :
elle donnait l'illusion d'un traitement qui n'existe pas. `default_base_unit` était une
méthode que personne n'appelait plus. Supprimer ce genre de code évite qu'un futur
développeur (ou moi) perde du temps à comprendre à quoi ça sert.

### Commit proposé

`suppression de code mort (clean_error_message, default_base_unit)`

---

# Étape 3 — Unifier le mapping groupe d'unités → unité de base

> Après l'étape 2, la correspondance `mass → g`, `volume → ml`... vit encore à
> **deux** endroits : la validation Ruby et le contrôleur Stimulus. Si l'un des deux
> change, l'autre se désynchronise silencieusement.

### Prompt à envoyer

- **Modèle conseillé** : Opus — effort moyen (refactoring à cheval sur Ruby et Stimulus, API Values à manier correctement)

```
**Qualité non négociable** : code simple, refactorisé, DRY, bien commenté, fiable, robuste, zéro code mort, bonnes pratiques Rails/Hotwire/HAML et conventions du projet.

Contexte : la correspondance unit_group → base_unit (mass→g, volume→ml, count→piece,
spoon→cac) est écrite en double :
- en Ruby dans Ingredient#base_unit_matches_unit_group (hash valid_units local à la
  méthode)
- en JavaScript dans ingredient_form_controller.js (static unitMap)
RubyCritic donne la note D à Ingredient avec une duplication Flay de 48. Si quelqu'un
ajoute un groupe d'unités, il doit penser aux deux endroits — et rien ne le signale.

Fichiers de contexte :
- app/models/ingredient.rb (lignes 34-40 pour l'enum, 158-174 pour la validation)
- app/javascript/controllers/ingredient_form_controller.js
- app/views/ingredients/_form.html.haml
- app/views/ingredients/_quick_form.html.haml

Demandes :
1. Dans Ingredient, extrais une constante publique et gelée
   BASE_UNITS = { "mass" => "g", "volume" => "ml", "count" => "piece",
   "spoon" => "cac" }.freeze
2. Réécris base_unit_matches_unit_group pour s'appuyer sur BASE_UNITS. Garde le même
   message d'erreur en français pour l'utilisatrice.
3. Côté JavaScript : supprime le hash unitMap codé en dur du contrôleur Stimulus et
   fais-lui lire la correspondance depuis une data-value Stimulus alimentée par
   Ingredient::BASE_UNITS dans les deux partials de formulaire. Utilise l'API Stimulus
   standard des Values (static values = { units: Object }) plutôt qu'un parsing manuel.
4. Après ce changement, ajouter un groupe d'unités ne doit demander de modifier QUE
   l'enum et BASE_UNITS dans le modèle.
```

### RSpec

À créer : `spec/models/ingredient_spec.rb` n'existe pas aujourd'hui.

```
Ajoute spec/models/ingredient_spec.rb couvrant :
- la validation base_unit_matches_unit_group (un cas valide et un cas invalide par
  groupe d'unités)
- la cohérence : BASE_UNITS a exactement une entrée par clé de l'enum unit_group
  (ce test casse si on ajoute un groupe en oubliant son unité)
```

À relancer :
```bash
cd /mnt/c/Caroline/easymeal && bundle exec rspec spec/models/ingredient_spec.rb && bundle exec rspec
```

### Vérification de ton côté

- `/ingredients/new` : change le groupe d'unités dans le select → le champ « unité de
  base » doit se remplir tout seul, pour les 4 groupes.
- Toujours sur `/ingredients/new` : force une unité incohérente (mets « kg » alors que
  le groupe est « Masse ») → tu dois voir le message d'erreur.
- Depuis le formulaire de recette, ouvre la **création rapide d'ingrédient** et refais
  le même test : ce partial doit se comporter pareil.

### Ce que ça fait

La même information était écrite deux fois, dans deux langages. On la déclare une
seule fois côté Ruby, et le JavaScript va la lire — c'est ce qu'on appelle le principe
DRY (*Don't Repeat Yourself*). Le test de cohérence ajouté est un filet de sécurité : il
échouera si quelqu'un ajoute un groupe d'unités sans son unité de base.

### Commit proposé

`mutualisation du mapping unité de base (Ruby + Stimulus)`

---

# Étape 4 — Utiliser I18n pour les dates françaises

> `MenusHelper` réimplémente à la main ce que Rails fait déjà nativement.

### Prompt à envoyer

- **Modèle conseillé** : Sonnet — effort faible (3 appels à remplacer, comportement natif de Rails)

```
**Qualité non négociable** : code simple, refactorisé, DRY, bien commenté, fiable, robuste, zéro code mort, bonnes pratiques Rails/Hotwire/HAML et conventions du projet.

Contexte : MenusHelper définit FRENCH_MONTHS (un tableau des 12 mois) et french_date
pour formater une date en "28 mars 2026". Or config/locales/fr.yml définit déjà
date.formats.long = "%d %B %Y" et date.month_names en français. Rails sait donc
produire exactement ce résultat via I18n.l(date, format: :long). Les 10 lignes du
helper sont une roue réinventée qui peut diverger des locales.

Fichiers de contexte :
- app/helpers/menus_helper.rb (lignes 27-35 et 79-87)
- config/locales/fr.yml (section date, lignes 2-14)
- app/views/menus/index.html.haml (ligne 67)
- app/views/menus/_history_card.html.haml (ligne 10)

Demandes :
1. Supprime la constante FRENCH_MONTHS et la méthode french_date de MenusHelper.
2. Remplace les 3 appels à french_date (menus_helper.rb ligne 85, index.html.haml
   ligne 67, _history_card.html.haml ligne 10) par le helper Rails l() avec
   format: :long.
3. Attention : les 3 appels reçoivent un created_at, donc un ActiveSupport::TimeWithZone
   et non une Date. Vérifie que le rendu reste identique (pas d'heure affichée) — si
   nécessaire, appelle .to_date.
4. Confirme par grep qu'aucun autre appel à french_date ne subsiste.
```

### RSpec

À relancer :
```bash
cd /mnt/c/Caroline/easymeal && bundle exec rspec spec/requests/menus_views_spec.rb && bundle exec rspec
```

### Vérification de ton côté

- Page `/menus` : la date « Créé le ... » sous le menu actif doit toujours afficher
  `28 mars 2026` (jour, mois en toutes lettres, année) — **pas** d'heure, **pas** de mois
  en anglais.
- Toujours sur `/menus`, dans la section historique : même vérification sur les cartes
  de menus archivés.
- Page d'un menu **non brouillon** (`/menus/:id`) : la ligne méta de l'en-tête doit
  afficher la date correctement.

### Ce que ça fait

Rails sait déjà traduire et formater les dates : il suffit de lui indiquer le format
voulu et il va chercher les noms de mois dans le fichier de traductions. Le helper
maison faisait le même travail en parallèle, avec le risque que les deux versions
divergent. On supprime donc la version maison au profit de l'outil natif.

### Commit proposé

`utilisation d'I18n pour le formatage des dates`

---

# Étape 5 — Déplacer les libellés de régime dans les locales

> Le projet a posé la règle « le français vit dans `config/locales/fr.yml` » pour les
> moments de repas. On l'applique aux régimes alimentaires.

### Prompt à envoyer

- **Modèle conseillé** : Sonnet — effort moyen (déplacement mécanique, mais 14 vues consomment ces deux helpers)

```
**Qualité non négociable** : code simple, refactorisé, DRY, bien commenté, fiable, robuste, zéro code mort, bonnes pratiques Rails/Hotwire/HAML et conventions du projet.

Contexte : MenusHelper stocke DIET_LABELS et DIET_DESCRIPTIONS, deux hashes de
français codés en dur dans du Ruby. Or CLAUDE.md pose la règle inverse pour le
vocabulaire des moments de repas : "le français vit dans config/locales/fr.yml".
Les libellés de régime doivent suivre la même règle. Ils sont utilisés dans
14 endroits de vues.

Fichiers de contexte :
- app/helpers/menus_helper.rb (lignes 3-25)
- config/locales/fr.yml (regarde comment meal_types est structuré, lignes 205-235)
- app/models/user.rb (pour l'enum default_diets)
- app/views/menus/_params_form.html.haml (lignes 44-45)

Demandes :
1. Ajoute une section `diets:` et `diets_descriptions:` dans config/locales/fr.yml,
   en suivant exactement la convention de nommage déjà utilisée par meal_types.
2. Réécris menu_diet_label et menu_diet_description pour lire dans les locales via
   I18n.t, en gardant leur comportement de repli actuel (humanize pour le label,
   chaîne vide pour la description) si la clé n'existe pas.
3. Supprime les constantes DIET_LABELS et DIET_DESCRIPTIONS.
4. NE change pas les signatures des deux méthodes ni leurs noms : 14 vues les
   appellent, elles doivent continuer à fonctionner sans modification.
```

### RSpec

À créer : `spec/helpers/menus_helper_spec.rb` n'existe pas.

```
Ajoute spec/helpers/menus_helper_spec.rb couvrant menu_diet_label et
menu_diet_description : les 4 régimes connus (omnivore, vegetarien, vegan,
pescetarien) plus le comportement de repli sur une clé inconnue.
```

À relancer :
```bash
cd /mnt/c/Caroline/easymeal && bundle exec rspec spec/helpers && bundle exec rspec
```

### Vérification de ton côté

- Page `/menus/new` : les 4 cartes de régime doivent afficher leur nom **et** leur
  description (« Végétarien / Sans viande ni poisson »).
- Page `/profile/preferences` : mêmes 4 cartes, même vérification.
- Page d'un menu actif : le badge de régime dans l'en-tête.
- Panneau de réglages d'un brouillon : le message de confirmation au changement de
  régime doit contenir le libellé en français entre guillemets.
- `/users` (admin) : la colonne régime de la liste des utilisateurs.

### Ce que ça fait

On sort les textes français du code Ruby pour les mettre dans le fichier de traduction,
là où ils devraient être. Concrètement, si tu veux corriger « Pescétarien » demain, tu
modifies une seule ligne dans `fr.yml` au lieu de fouiller dans un helper. C'est aussi
ce qui rendrait une traduction anglaise possible plus tard sans retoucher le code.

### Commit proposé

`libellés de régime déplacés dans les locales`

---

# Étape 6 — Déplacer les traductions Ingredient dans les locales

> Même opération que l'étape 5, mais sur les 21 rayons et 4 groupes d'unités.

### Prompt à envoyer

- **Modèle conseillé** : Opus — effort moyen (suppression d'une surcharge Rails ; la liste de courses en dépend indirectement)

```
**Qualité non négociable** : code simple, refactorisé, DRY, bien commenté, fiable, robuste, zéro code mort, bonnes pratiques Rails/Hotwire/HAML et conventions du projet.

Contexte : Ingredient surcharge self.human_attribute_name pour router
"category.<clé>" et "unit_group.<clé>" vers deux tables de correspondance privées
écrites en dur en Ruby (21 rayons + 4 groupes d'unités). C'est du français dans du
code, contraire à la règle du projet. Rails sait faire ça nativement : les enums se
traduisent via activerecord.attributes.ingredient.<enum>.<clé> dans les locales, sans
aucune surcharge.

Fichiers de contexte :
- app/models/ingredient.rb (lignes 42-53 et 119-156)
- config/locales/fr.yml (section activerecord, à partir de la ligne 21)
- app/views/ingredients/index.html.haml (lignes 16 et 52)
- app/views/menus/_grocery_section.html.haml (ligne 6)

Demandes :
1. Déplace les 21 rayons et les 4 groupes d'unités dans config/locales/fr.yml, sous
   activerecord.attributes.ingredient.category et .unit_group, en respectant la
   structure existante du fichier.
2. Supprime la surcharge self.human_attribute_name ET le bloc `class << self ... end`
   contenant category_translations et unit_group_translations.
3. Vérifie que les 8 appels existants à Ingredient.human_attribute_name("category.X")
   dans les vues continuent de renvoyer le bon libellé sans être modifiés — c'est le
   comportement natif de Rails pour les enums, mais confirme-le par un test.
4. Attention au cas particulier : menus/_grocery_section.html.haml traduit une
   catégorie de GroceryItem (pas d'Ingredient) via Ingredient.human_attribute_name.
   Vérifie que ce cas fonctionne toujours.
```

### RSpec

À compléter : `spec/models/ingredient_spec.rb` (créé à l'étape 3).

```
Ajoute au spec Ingredient des exemples vérifiant que
Ingredient.human_attribute_name("category.fruits_legumes") renvoie
"Fruits et légumes", que chaque clé de l'enum category a une traduction, et idem
pour unit_group.
```

À relancer :
```bash
cd /mnt/c/Caroline/easymeal && bundle exec rspec spec/models/ingredient_spec.rb && bundle exec rspec
```

### Vérification de ton côté

- `/ingredients` : le filtre « Tous les rayons » doit lister les 21 rayons en français,
  et la colonne rayon de chaque ligne doit être remplie.
- `/ingredients/:id` : rayon et groupe d'unités affichés en français.
- `/ingredients/new` : les deux selects du formulaire.
- **Le plus important** — la liste de courses d'un menu actif (`/menus/:id/grocery`) :
  les titres de section (« Fruits et légumes », « Épicerie salée »...) doivent être
  corrects, ainsi que le select de changement de rayon.

### Ce que ça fait

Rails traduit automatiquement les valeurs d'enum s'il les trouve dans le fichier de
locales, au bon emplacement. Le modèle interceptait ces appels pour aller chercher dans
ses propres tables — un contournement devenu inutile. On supprime 40 lignes de Ruby en
laissant le framework faire son travail.

### Commit proposé

`traductions Ingredient déplacées dans les locales`

---

# Étape 7 — Mettre en cache la lecture des fichiers SVG

> Problème de performance, pas de propreté : chaque icône déclenche un accès disque
> à chaque affichage de page.

### Prompt à envoyer

- **Modèle conseillé** : Opus — effort moyen (arbitrage à faire entre cache en production et confort de développement)

```
**Qualité non négociable** : code simple, refactorisé, DRY, bien commenté, fiable, robuste, zéro code mort, bonnes pratiques Rails/Hotwire/HAML et conventions du projet.

Contexte : ApplicationHelper#inline_svg fait un File.exist? puis un File.read à
chaque appel. Comme cette méthode est appelée plusieurs fois par page pour afficher
les icônes, cela produit plusieurs accès disque par requête, y compris en production
où les fichiers ne changent jamais.

Fichiers de contexte :
- app/helpers/application_helper.rb (lignes 108-128)
- config/environments/production.rb
- config/environments/development.rb

Demandes :
1. Mémorise le contenu brut des fichiers SVG pour éviter de relire le disque à chaque
   appel. Le cache doit porter sur la lecture du fichier uniquement, pas sur le résultat
   final (qui dépend des paramètres color/color2/size/css_class).
2. IMPORTANT : le cache ne doit pas gêner le développement. Si j'ajoute ou modifie un
   SVG dans app/assets/images/icones/, je dois voir le changement sans redémarrer le
   serveur. Choisis l'approche adaptée (cache actif en production seulement, ou
   invalidation sur mtime) et explique-moi en une phrase laquelle tu as retenue et
   pourquoi.
3. Conserve strictement le comportement actuel : renvoi d'une chaîne html_safe vide si
   le fichier n'existe pas, et injection identique des attributs class/style/aria-hidden.
4. Ne touche pas à svg_icon (les icônes Feather sont déjà en constante, aucun accès
   disque).
```

### RSpec

À compléter : `spec/helpers/application_helper_spec.rb` ne teste aujourd'hui que
`#greeting_context`.

```
Ajoute au spec ApplicationHelper des exemples pour inline_svg :
- une icône existante renvoie du SVG contenant les classes attendues
- une icône inexistante renvoie une chaîne vide
- les options color, color2 et size produisent bien l'attribut style attendu
```

À relancer :
```bash
cd /mnt/c/Caroline/easymeal && bundle exec rspec spec/helpers/application_helper_spec.rb && bundle exec rspec
```

### Vérification de ton côté

- Toutes les pages : les icônes doivent s'afficher normalement, aux bonnes couleurs et
  aux bonnes tailles (page d'accueil, catalogue de recettes, menus, liste de courses).
- **Test spécifique au cache** : ouvre un fichier de `app/assets/images/icones/`,
  modifie-le légèrement, recharge la page en développement → tu dois voir le changement
  sans redémarrer le serveur Rails.

### Ce que ça fait

Lire un fichier sur le disque est lent comparé à lire de la mémoire. Comme les icônes
ne changent jamais une fois l'application déployée, on garde leur contenu en mémoire
après la première lecture. Le point d'attention est le développement : il ne faut pas
qu'un cache trop agressif t'empêche de voir tes modifications d'icônes.

### Commit proposé

`mise en cache de la lecture des SVG inline`

---

# Étape 8 — Restreindre le rescue trop large de transition_menu

> Un vrai bug latent : une erreur de programmation se transforme aujourd'hui en
> message d'interface.

### Prompt à envoyer

- **Modèle conseillé** : Opus — effort élevé (il faut tracer ce que lèvent réellement les transitions avant de restreindre quoi que ce soit)

```
**Qualité non négociable** : code simple, refactorisé, DRY, bien commenté, fiable, robuste, zéro code mort, bonnes pratiques Rails/Hotwire/HAML et conventions du projet.

Contexte : MenusController#transition_menu (méthode privée) enveloppe activate!,
reactivate! et revert_to_draft! dans un `rescue StandardError`. StandardError est la
classe parente de presque toutes les erreurs Ruby : un NoMethodError ou un
ActiveRecord::RecordInvalid inattendu serait donc masqué et affiché à l'utilisatrice
sous la forme "Impossible d'activer le menu : undefined method ...". Le bug ne
remonterait ni dans les logs d'erreur ni dans un outil de suivi.

Fichiers de contexte :
- app/controllers/menus_controller.rb (lignes 104-131 et 233-241)
- app/models/menu.rb (les méthodes activate!, reactivate!, revert_to_draft!,
  archive!, et ce qu'elles lèvent réellement)

Demandes :
1. Identifie précisément quelles exceptions les trois transitions peuvent lever
   légitimement (échec de validation métier, garde d'état...). Liste-les-moi.
2. Restreins le rescue à ces seules exceptions. Une erreur de programmation doit
   remonter normalement en page 500.
3. Si ces transitions lèvent aujourd'hui des exceptions génériques (RuntimeError ou
   StandardError levées à la main), propose-moi plutôt une classe d'erreur métier
   dédiée dans le modèle Menu, sur le modèle de Menus::NoCandidatesError qui existe
   déjà dans le projet.
4. Le message flash vu par l'utilisatrice ne doit pas changer pour les échecs métier
   légitimes.
```

### RSpec

À compléter : `spec/models/menu_spec.rb` et les specs de requêtes menus.

```
Vérifie que les specs existants couvrent le cas d'échec d'une transition. Sinon,
ajoute un exemple par transition : un échec métier produit bien le flash d'alerte
attendu et une redirection, sans lever d'exception.
```

À relancer :
```bash
cd /mnt/c/Caroline/easymeal && bundle exec rspec spec/models/menu_spec.rb spec/requests/menus_revert_to_draft_spec.rb spec/requests/menus_views_spec.rb && bundle exec rspec
```

### Vérification de ton côté

- **Chemin nominal** : valide un menu brouillon → tu dois arriver sur la liste de
  courses avec le message « Menu activé ! ».
- Repasse un menu actif en brouillon → message « Menu repassé en brouillon ».
- Réactive un menu archivé → message « Menu réactivé ! ».
- Si tu sais provoquer un échec métier (par exemple activer un menu vide), vérifie
  que le message d'alerte reste lisible et en français.

### Ce que ça fait

`rescue StandardError` est un filet trop large : il attrape aussi bien les erreurs
prévues (« ce menu ne peut pas être activé ») que les bugs de programmation. Résultat,
un vrai bug s'affiche comme un message poli à l'utilisatrice et personne ne le
remarque. On ne rattrape désormais que les erreurs métier attendues ; le reste remonte
normalement pour qu'on puisse le corriger.

### Commit proposé

`rescue restreint aux erreurs métier dans les transitions de menu`

---

# Étape 9 — Alléger RecipesController#index

> La seule action de contrôleur réellement trop chargée : 8 variables d'instance et
> 5 requêtes en ligne.

### Prompt à envoyer

- **Modèle conseillé** : Opus — effort élevé (choix d'architecture + optimisations anti-N+1 à déplacer sans les casser)

```
**Qualité non négociable** : code simple, refactorisé, DRY, bien commenté, fiable, robuste, zéro code mort, bonnes pratiques Rails/Hotwire/HAML et conventions du projet.

Contexte : RecipesController#index fait 28 lignes, assigne 8 variables d'instance
(@pagy, @recipes, @tags, @favorited_ids, @current_month, @seasonal_ids, plus celles
posées par load_draft_data et load_draft_meals) et exécute 5 requêtes en ligne.
RubyCritic la signale en TooManyStatements et TooManyInstanceVariables ; le fichier
est noté C avec une complexité de 192. Les optimisations N+1 en place (Set d'IDs
préchargés, cache des tags) sont bonnes et doivent être conservées telles quelles :
l'objectif est de les déplacer, pas de les changer.

Fichiers de contexte :
- app/controllers/recipes_controller.rb (lignes 14-43 et 123-145)
- app/controllers/concerns/recipes/draft_manageable.rb
- app/services/recipes/filter_service.rb
- app/views/recipes/index.html.haml (pour voir quelles variables la vue consomme)

Demandes :
1. Extrais la construction du catalogue dans un objet dédié — soit un service
   Recipes::CatalogQuery, soit un presenter — cohérent avec l'architecture existante
   du projet (regarde comment Recipes::FilterService et Menus::GenerateService sont
   écrits et suis la même convention).
2. L'action index doit se réduire à : autoriser, appeler l'objet, exposer le minimum
   de variables à la vue.
3. Ne change AUCUNE optimisation de performance : le Set @favorited_ids, le Set
   @seasonal_ids et le Rails.cache des tags doivent produire exactement le même nombre
   de requêtes SQL qu'avant. Ce point est prioritaire sur l'élégance du découpage.
4. Vérifie ensuite si le before_action :set_recipe est encore utile : il ne fait
   qu'appeler le lecteur mémoïsé `recipe`, que authorize_recipe et les concerns
   appellent déjà en première ligne. Si tu confirmes qu'il est redondant, supprime-le ;
   sinon explique-moi pourquoi il doit rester.
```

### RSpec

À relancer :
```bash
cd /mnt/c/Caroline/easymeal && bundle exec rspec spec/requests/recipes_meal_types_spec.rb spec/requests/recipes_draft_rail_spec.rb spec/requests/recipe_drafts_spec.rb spec/services/recipes/filter_service_spec.rb && bundle exec rspec
```

Si un `spec/services/recipes/catalog_query_spec.rb` est créé, l'ajouter à la liste.

### Vérification de ton côté

Le catalogue est la page la plus riche du site, teste-la à fond :
- `/recipes` : la liste s'affiche, la pagination fonctionne.
- Filtre par **tag**, puis par **régime**, puis le tri — chaque filtre doit fonctionner.
- Filtre **« Mes favoris »** → seules tes recettes favorites doivent apparaître.
- Le **cœur** des favoris doit être rempli sur les bonnes cartes.
- Le badge **« De saison »** doit apparaître sur les mêmes recettes qu'avant.
- Avec un menu brouillon en cours : le **rail latéral** du menu à valider doit s'afficher
  avec ses vignettes, et le bouton Ajouter/Retirer doit être dans le bon état.
- **Déconnecte-toi** et recharge `/recipes` : la page doit fonctionner sans favoris ni rail.

### Ce que ça fait

Une action de contrôleur doit répondre à « quoi faire », pas « comment ». Ici elle
contient toute la mécanique de construction du catalogue. On déplace cette mécanique
dans un objet dédié, testable isolément, et l'action redevient lisible en trois lignes.
Attention : les optimisations qui évitent les requêtes SQL en boucle sont fragiles, d'où
l'insistance à ne pas les modifier.

### Commit proposé

`extraction de la construction du catalogue de recettes`

---

# Étape 10 — Filet de sécurité avant de découper ExtractorService

> `ExtractorService` est le pire fichier du projet (note D, complexité 236, 53 smells)
> et il n'a **aucun spec**. On écrit les tests **avant** de le découper, sinon on
> refactore à l'aveugle.

### Prompt à envoyer

- **Modèle conseillé** : Opus — effort élevé (292 lignes à couvrir, dont des cas limites de parsing et de réseau à simuler)

```
**Qualité non négociable** : code simple, refactorisé, DRY, bien commenté, fiable, robuste, zéro code mort, bonnes pratiques Rails/Hotwire/HAML et conventions du projet.

Contexte : Recipes::ExtractorService est le fichier le plus problématique du projet
(note RubyCritic D, complexité 236, 53 smells, 292 lignes) et il n'existe aucun
spec/services/recipes/extractor_service_spec.rb. Je veux le découper aux étapes
suivantes, mais refactorer du code non testé est dangereux. Cette étape ne change donc
AUCUNE ligne de app/ : elle écrit uniquement des tests de caractérisation, c'est-à-dire
des tests qui figent le comportement actuel pour détecter toute régression pendant le
découpage.

Fichiers de contexte :
- app/services/recipes/extractor_service.rb
- app/controllers/recipe_imports_controller.rb
- spec/requests/recipe_imports_spec.rb (pour voir comment le service y est déjà simulé)
- spec/services/menus/generate_service_spec.rb (pour suivre la convention de specs
  de service du projet)
- Gemfile (vérifie si webmock ou vcr est disponible pour simuler les appels HTTP)

Demandes :
1. Crée spec/services/recipes/extractor_service_spec.rb. Aucun appel réseau réel ne
   doit être fait : simule les réponses HTTP.
2. Couvre en priorité les méthodes de parsing pur, les plus faciles à figer :
   - parse_yield ("4 personnes", "4-6 parts", texte sans chiffre, nil)
   - parse_iso_duration ("PT1H30M", "PT45M", "PT2H", nil, chaîne invalide)
   - format_instructions (tableau de Hash, tableau de String, mélange, vide)
   - recipe_type? (@type string, @type tableau, données non Hash)
3. Couvre ensuite le chemin from_url avec du HTML simulé : une page contenant du
   schema.org valide, une page avec @graph, une page sans schema.org, une page dont le
   JSON-LD est invalide.
4. Couvre les cas d'erreur de fetch_html : URL non http/https, redirection, dépassement
   du nombre de redirections, code de réponse non 200.
5. Couvre le repli de parse_ingredients_with_claude quand l'appel à l'IA échoue (il
   doit renvoyer les chaînes brutes).
6. Si tu dois utiliser `send` pour tester des méthodes privées, fais-le et signale-le
   en commentaire : ces tests sont temporaires, les méthodes deviendront publiques sur
   leurs nouvelles classes aux étapes 11 et 12.
7. Ne modifie AUCUN fichier de app/. Si un comportement actuel te paraît être un bug,
   écris le test qui fige le comportement ACTUEL et signale-le-moi séparément.
```

### RSpec

À créer : `spec/services/recipes/extractor_service_spec.rb`.

```bash
cd /mnt/c/Caroline/easymeal && bundle exec rspec spec/services/recipes/extractor_service_spec.rb && bundle exec rspec
```

Note bien le nouveau total d'exemples : c'est ta nouvelle baseline pour les étapes 11 et 12.

### Vérification de ton côté

Rien de visuel à ce stade (aucun code applicatif modifié). Vérifie simplement que la
suite est verte et que le nombre d'exemples a augmenté.

### Ce que ça fait

Un « test de caractérisation » ne vérifie pas que le code est *correct*, mais qu'il se
comporte *comme aujourd'hui*. C'est le filet de sécurité indispensable avant de
réorganiser du code : si le découpage casse quelque chose, un test rougit immédiatement
au lieu que le bug apparaisse en production trois semaines plus tard.

### Commit proposé

`tests de caractérisation pour ExtractorService`

---

# Étape 11 — Découper ExtractorService (1/2) : HTTP et schema.org

> Premier tiers du découpage. On sort ce qui n'a rien à voir avec l'IA.

### Prompt à envoyer

- **Modèle conseillé** : Opus — effort élevé (extraction de deux classes + déplacement des specs, sur le fichier le plus complexe du projet)

```
**Qualité non négociable** : code simple, refactorisé, DRY, bien commenté, fiable, robuste, zéro code mort, bonnes pratiques Rails/Hotwire/HAML et conventions du projet.

Contexte : Recipes::ExtractorService fait quatre métiers dans une seule classe :
(1) client HTTP, (2) parseur schema.org, (3) constructeur de prompts, (4) client de
l'API Claude. On sort les deux premiers dans cette étape. Les tests de caractérisation
de l'étape 10 sont le filet de sécurité : ils doivent rester verts.

Fichiers de contexte :
- app/services/recipes/extractor_service.rb (lignes 40-147)
- spec/services/recipes/extractor_service_spec.rb
- app/services/menus/generate_service.rb (pour la convention d'objet de service
  du projet)

Demandes :
1. Extrais Recipes::PageFetcher : tout le HTTP de fetch_html (validation d'URL,
   redirections avec limite, timeouts, forçage d'encodage UTF-8, messages d'erreur en
   français).
2. Extrais Recipes::SchemaOrgParser : parse_schema_org, recipe_type?, parse_yield,
   parse_iso_duration, format_instructions et extract_text. Ces méthodes deviennent
   publiques sur la nouvelle classe — c'est ce qui fait disparaître les smells
   UtilityFunction et FeatureEnvy signalés par Reek.
3. Décide où vit l'exception ExtractionError pour que les deux nouvelles classes
   puissent la lever sans dépendre d'ExtractorService. Explique-moi ton choix en une
   phrase.
4. ExtractorService garde from_url, from_photo, extract_from_schema et tout ce qui
   touche à Claude — on s'en occupe à l'étape 12. Son interface publique
   (ExtractorService.from_url / .from_photo) ne doit PAS changer.
5. Déplace les tests correspondants dans spec/services/recipes/page_fetcher_spec.rb et
   spec/services/recipes/schema_org_parser_spec.rb. Les tests qui utilisaient `send`
   pour atteindre des méthodes privées doivent maintenant les appeler normalement.
6. Aucun `send` ne doit subsister dans les specs de ces deux nouvelles classes.
```

### RSpec

À déplacer/créer : `spec/services/recipes/page_fetcher_spec.rb`,
`spec/services/recipes/schema_org_parser_spec.rb`.

```bash
cd /mnt/c/Caroline/easymeal && bundle exec rspec spec/services spec/requests/recipe_imports_spec.rb && bundle exec rspec
```

Le nombre total d'exemples doit rester **identique ou supérieur** à celui de l'étape 10.

### Vérification de ton côté

- Va sur la page d'import de recette et importe une recette **depuis une URL** d'un site
  qui expose du schema.org (Marmiton, 750g...) → la recette doit se pré-remplir comme
  avant : nom, description, temps, portions, instructions numérotées, ingrédients.
- Teste une **URL invalide** (`ftp://...` ou une adresse inexistante) → tu dois voir un
  message d'erreur en français, pas une page 500.
- Teste une URL d'une page **sans schema.org** (un blog quelconque) → l'extraction doit
  basculer sur l'IA et fonctionner quand même.

### Ce que ça fait

Une classe doit avoir une seule raison de changer. Celle-ci en avait quatre : modifier
la gestion des redirections HTTP obligeait à ouvrir le même fichier que modifier un
prompt d'IA. On sépare donc « aller chercher une page web » et « lire les données
structurées d'une page » en deux objets distincts, chacun testable seul.

### Commit proposé

`extraction de PageFetcher et SchemaOrgParser`

---

# Étape 12 — Découper ExtractorService (2/2) : prompts et client Claude

> Dernier tiers. C'est aussi ici qu'on traite la duplication des « règles strictes ».

### Prompt à envoyer

- **Modèle conseillé** : Opus — effort élevé (fin du découpage, mutualisation DRY des prompts IA, plus une analyse à me rendre)

```
**Qualité non négociable** : code simple, refactorisé, DRY, bien commenté, fiable, robuste, zéro code mort, bonnes pratiques Rails/Hotwire/HAML et conventions du projet.

Contexte : après l'étape 11, ExtractorService contient encore deux métiers : la
construction des prompts envoyés à Claude et le client HTTP de l'API Claude. Il reste
aussi une vraie duplication : les 4 "Règles strictes" (difficulty, diet, unit,
total_time_minutes) sont écrites mot pour mot deux fois, dans text_messages
(lignes 181-186) et photo_messages (lignes 208-213).

Fichiers de contexte :
- app/services/recipes/extractor_service.rb (état après l'étape 11)
- spec/services/recipes/extractor_service_spec.rb
- .env.example ou config/ (pour voir comment ANTHROPIC_API_KEY est déclarée)

Demandes :
1. Extrais Recipes::ClaudePrompts : text_messages, photo_messages,
   parse_ingredients_with_claude (la partie prompt seulement) et json_schema_example.
   Mutualise les 4 "Règles strictes" dupliquées en un seul endroit — c'est la
   correction DRY principale de cette étape.
2. Extrais Recipes::ClaudeClient : call_claude, la gestion de la clé API, les timeouts,
   le nettoyage des blocs markdown autour du JSON, et toute la traduction des erreurs
   API en ExtractionError avec messages en français.
3. ExtractorService ne garde que l'orchestration : from_url, from_photo,
   extract_from_schema. Son interface publique ne change pas.
4. La méthode extract_with_claude ne fait que déléguer à call_claude — supprime-la si
   elle n'apporte rien après le découpage.
5. Sépare les specs en spec/services/recipes/claude_prompts_spec.rb et
   claude_client_spec.rb.

Point à me signaler SANS le corriger dans ce commit (je déciderai après) :
- Le modèle utilisé est "claude-sonnet-4-6". Il est valide et actif, donc rien ne
  casse. Mais claude-sonnet-5 existe maintenant et est meilleur en extraction
  structurée.
- L'API Claude est appelée en Net::HTTP brut alors que le gem officiel `anthropic`
  existe pour Ruby, ce qui supprimerait une bonne partie du code de ClaudeClient.
- Le nettoyage manuel des blocs markdown (les gsub sur ```json) pourrait être remplacé
  par les sorties structurées de l'API, qui garantissent du JSON valide.
Fais-moi une estimation de l'effort pour chacun de ces trois points, sans y toucher.
```

### RSpec

À créer : `spec/services/recipes/claude_prompts_spec.rb`,
`spec/services/recipes/claude_client_spec.rb`.

```bash
cd /mnt/c/Caroline/easymeal && bundle exec rspec spec/services spec/requests/recipe_imports_spec.rb && bundle exec rspec
```

### Vérification de ton côté

Rejoue **tous** les tests de l'étape 11, puis :
- Importe une recette **depuis une photo** → l'extraction doit fonctionner et
  pré-remplir le formulaire.
- Importe une URL **sans schema.org** (un blog) → le chemin « texte envoyé à l'IA »
  doit fonctionner.
- Importe une URL **avec schema.org mais ingrédients en texte brut** → les ingrédients
  doivent ressortir structurés (nom / quantité / unité), pas en chaînes brutes.
- **Test d'erreur** : vide temporairement `ANTHROPIC_API_KEY` dans ton `.env`, relance
  le serveur, tente un import photo → tu dois voir un message d'erreur clair en
  français mentionnant la variable manquante, pas une page 500. Remets ta clé ensuite.

### Vérification finale du chantier

```bash
cd /mnt/c/Caroline/easymeal && bundle exec rspec && bundle exec rubycritic app --no-browser
```

Puis ouvre `tmp/rubycritic/overview.html` depuis Windows. Attendu : plus aucun fichier
en note D, `ExtractorService` disparu du haut du classement de complexité, et un score
global au-dessus de 88.77.

### Ce que ça fait

On termine le découpage : construire un prompt et appeler une API sont deux métiers
différents, désormais dans deux classes distinctes. Au passage, les règles envoyées à
l'IA n'étaient écrites qu'à moitié en double — si on en corrigeait une sans l'autre,
l'import photo et l'import URL se seraient comportés différemment sans que personne
ne le remarque.

### Commit proposé

`extraction de ClaudePrompts et ClaudeClient`

---

## Récapitulatif

| # | Étape | Effort | Risque |
|---|---|---|---|
| 1 | SimpleCov | 15 min | nul |
| 2 | Code mort | 15 min | nul |
| 3 | Mapping unités (Ruby + JS) | 45 min | faible |
| 4 | Dates via I18n | 20 min | faible |
| 5 | Libellés régimes → locales | 30 min | faible |
| 6 | Traductions Ingredient → locales | 45 min | moyen (liste de courses) |
| 7 | Cache SVG | 30 min | faible |
| 8 | rescue transition_menu | 30 min | moyen |
| 9 | RecipesController#index | 1 h 30 | moyen (perf) |
| 10 | Specs ExtractorService | 1 h 30 | nul |
| 11 | Découpage 1/2 | 1 h | moyen |
| 12 | Découpage 2/2 | 1 h | moyen |

Les étapes 1 à 8 sont indépendantes : tu peux t'arrêter, reprendre, ou en sauter une.
Les étapes 10 à 12 forment un bloc — ne commence pas la 11 sans avoir fini la 10.

### À ignorer dans le rapport RubyCritic

Environ la moitié des 281 smells sont des faux positifs pour du Rails :

- **UtilityFunction (42) et FeatureEnvy (19)** — Reek signale toute méthode de module
  qui n'utilise pas d'état d'instance. C'est la définition même d'un helper Rails.
  `MenusHelper` cumule 26 de ces smells alors qu'il est bien écrit.
- **IrresponsibleModule (30)** — « ce module n'a pas de commentaire en tête ». Cosmétique.
- **MissingSafeMethod (10)** — les méthodes `!` de `Menu` (`activate!`, `archive!`...)
  sont des commandes qui lèvent en cas d'échec : c'est exactement la convention Rails.
- **RepeatedConditional (4) dans MenusController** — la condition est déjà extraite dans
  la méthode `form_params_present?`. Rien à faire.
