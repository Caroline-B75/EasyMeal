# 🚀 Commandes EasyMeal - Guide rapide

## 📂 Ouvrir et démarrer le projet

```bash
# 1. Aller dans le projet
cd /mnt/c/Caroline/easymeal

# 2. Activer Ruby avec RVM
rvm use 3.3.7@easymeal --create -> la première fois seulement
rvm use 3.3.7@easymeal

# 3. Installer/mettre à jour les gems seulement si nécessaire
bundle install

# 4. Démarrer PostgreSQL
sudo service postgresql start

# 5. Préparer la base de données
bin/rails db:prepare

# 6. Lancer le serveur
bin/rails server
```

## en RAILS CONSOLE

Nouveau terminal :
cd /mnt/c/Caroline/easymeal
rvm use 3.3.7@easymeal --create
rails c

-> pour afficher "joliment" les attributs il faut mettre "ap" avant la commande. Ex:
ap User.first

→ Application accessible sur **http://localhost:3000**

---

## 🔄 Workflow Git complet (SourceTree + Console)

### ✨ Workflow en 4 étapes

#### **ÉTAPE 1 : Créer une nouvelle branche**

**Dans SourceTree :**

1. Assure-toi d'être sur la branche `main` (double-clic sur `main` dans la liste des branches)
2. Clique sur le bouton **Branche** (en haut)
3. Nomme ta branche (ex: `feature/recipes`, `fix/login-bug`)
4. Coche **Créer une nouvelle branche**
5. Clique sur **Créer une branche**

**Alternative en console :**

```bash
git checkout main
git checkout -b feature/nom-de-ma-fonctionnalite
```

---

#### **ÉTAPE 2 : Faire des commits**

**Dans SourceTree (recommandé) :**

**Pour commiter TOUS les fichiers modifiés :**

1. Dans l'onglet **État des fichiers**, coche la case tout en haut (à côté de "Fichiers non indexés")
2. Tous les fichiers passent dans "Fichiers indexés"
3. En bas, écris ton message de commit (ex: `feat: ajout du modèle Recipe`)
4. Clique sur **Commit**

**Pour commiter QUELQUES fichiers seulement :**

1. Dans "Fichiers non indexés", coche **uniquement** les fichiers que tu veux commiter
2. Ils passent dans "Fichiers indexés"
3. En bas, écris ton message de commit
4. Clique sur **Commit**

**Alternative en console :**

```bash
# Commiter TOUS les fichiers
git add .
git commit -m "feat: description de la modification"

# Commiter QUELQUES fichiers
git add chemin/vers/fichier1.rb
git add chemin/vers/fichier2.rb
git commit -m "feat: description de la modification"
```

**Messages de commit conventionnels :**

- `feat: ...` → Nouvelle fonctionnalité
- `fix: ...` → Correction de bug
- `refactor: ...` → Refactoring
- `test: ...` → Tests
- `docs: ...` → Documentation
- `style: ...` → Style/formatage
- `chore: ...` → Tâches diverses

**→ Répète cette étape autant de fois que nécessaire pendant ton développement**

---

#### **ÉTAPE 3 : Merger dans main et pousser sur GitHub**

**En console (obligatoire pour éviter l'éditeur nano) :**

```bash
# 1. Aller sur main
git checkout main

# 2. Merger ta branche (remplace "nom-branche" par le nom de ta branche)
git merge --no-ff nom-branche -m "Merge branch 'nom-branche' - Description courte"

# 3. Pousser vers GitHub
git push origin main
```

**Exemple concret :**

```bash
git checkout main
git merge --no-ff feature/recipes -m "Merge branch 'feature/recipes' - Ajout modèle Recipe"
git push origin main  ##ça va demander le username : Caroline-B75 et le mot de passe sera le token à créer dans github comme ceci :
# Sur Github — Créer un Personal Access Token sur GitHub :
# Va sur github.com → connecte-toi avec ton mot de passe habituel
# Clique sur ta photo de profil (en haut à droite) → Settings
# Dans le menu gauche, tout en bas → Developer settings
# Personal access tokens → Tokens (classic)
# Generate new token → Generate new token (classic)
# Donne-lui un nom (ex: easymeal-wsl), une expiration, et coche la case repo (accès complet aux repos)
# Clique Generate token
# ⚠️ Copie le token immédiatement — il ne s'affichera qu'une seule fois !
# Étape 2 — Utiliser le token à la place du mot de passe
# Quand Git te demande le mot de passe, colle ton token à la place :
# Username: Caroline-B75
# Password: <colle ton token ici>
```

---

#### **ÉTAPE 4 : Supprimer la branche**

**En console (recommandé) :**

```bash
# Supprimer la branche locale
git branch -d nom-branche
```

**Dans SourceTree :**

1. Fais un clic droit sur ta branche (dans la liste des branches à gauche)
2. Sélectionne **Supprimer la branche**
3. Confirme

---

### 📋 Résumé du workflow complet

```
1. SourceTree : Créer branche "feature/ma-fonctionnalite" depuis main
                ↓
2. SourceTree : Faire des commits (plusieurs fois si besoin)
                ↓
3. Console    : git checkout main
                git merge --no-ff feature/ma-fonctionnalite -m "Merge branch '...' - Description"
                git push origin main
                ↓
4. Console    : git branch -d feature/ma-fonctionnalite
```

---

## 🌿 Git - Gestion des branches (commandes utiles)

### Voir les branches

```bash
# Lister toutes les branches locales
git branch

# Lister toutes les branches (locales + distantes)
git branch -a

# Voir la branche actuelle
git branch --show-current
```

### Changer de branche

**Dans SourceTree :** Double-clic sur le nom de la branche

**En console :**

```bash
git checkout nom-de-la-branche
```

### Supprimer une branche distante (si elle existe sur GitHub)

```bash
git push origin --delete nom-de-la-branche
```

---

## 💾 Git - Autres commandes utiles

### Voir l'état des fichiers

```bash
# Voir les fichiers modifiés
git status

# Voir les différences détaillées
git diff

# Voir les différences des fichiers stagés
git diff --staged
```

### Annuler des modifications

```bash
# Annuler les modifications d'un fichier (avant add/commit)
git restore chemin/vers/fichier.rb

# Annuler le dernier commit (garde les modifications)
git reset --soft HEAD~1

# Annuler le dernier commit (supprime les modifications - ATTENTION!)
git reset --hard HEAD~1
```

---

## 📜 Git - Historique

```bash
# Voir l'historique des commits
git log

# Historique compact et graphique (recommandé)
git log --oneline --graph --decorate --all

# Voir les 5 derniers commits
git log -5 --oneline

# Voir les détails d'un commit spécifique
git show <hash-du-commit>
```

---

## 🗃️ Git - Stash (sauvegarder temporairement)

```bash
# Sauvegarder les modifications en cours
git stash push -m "work in progress"

# Lister les stashs
git stash list

# Récupérer le dernier stash
git stash pop

# Récupérer un stash spécifique
git stash pop stash@{0}

# Supprimer tous les stashs
git stash clear
```

---

## 🗄️ Base de données

```bash
# Créer la base de données
bin/rails db:create

# Exécuter les migrations
bin/rails db:migrate

# Annuler la dernière migration
bin/rails db:rollback

# Annuler plusieurs migrations
bin/rails db:rollback STEP=3

# Réinitialiser la base (DROP + CREATE + MIGRATE)
bin/rails db:reset

# Charger les seeds
bin/rails db:seed

# Préparer la base (CREATE si nécessaire + MIGRATE)
bin/rails db:prepare

# Voir le statut des migrations
bin/rails db:migrate:status
```

---

## 🛠️ Rails - Génération de code

```bash
# Générer un modèle
bin/rails g model Recipe name:string description:text

# Générer un contrôleur
bin/rails g controller Recipes index show

# Générer une migration
bin/rails g migration AddAdminToUsers admin:boolean

# Générer un scaffold (modèle + contrôleur + vues)
bin/rails g scaffold Recipe name:string
```

---

## 🔍 Rails - Utilitaires

```bash
# Console Rails (pour tester du code Ruby/ActiveRecord)
bin/rails console
# OU en mode lecture seule
bin/rails console --sandbox

# Voir toutes les routes
bin/rails routes

# Chercher une route spécifique
bin/rails routes | grep recipes

# Informations sur l'environnement Rails
bin/rails about

# Nettoyer les logs et fichiers temporaires
bin/rails log:clear
bin/rails tmp:clear
```

---

## 🧪 Tests

```bash
# Lancer tous les tests RSpec
bundle exec rspec

# Lancer un fichier de test spécifique
bundle exec rspec spec/models/recipe_spec.rb

# Lancer un test spécifique (par ligne)
bundle exec rspec spec/models/recipe_spec.rb:12

# Lancer les tests avec détails
bundle exec rspec --format documentation
```

---

## 🔒 Sécurité et qualité

```bash
# Analyse de sécurité avec Brakeman
bundle exec brakeman

# Audit des dépendances
bundle exec bundler-audit

# Linter Ruby (Rubocop)
bundle exec rubocop

# Auto-corriger les problèmes Rubocop
bundle exec rubocop -a
```

---

## 📦 Gems

```bash
# Installer les gems du Gemfile
bundle install

# Mettre à jour une gem spécifique
bundle update nom-de-la-gem

# Mettre à jour toutes les gems
bundle update

# Voir les gems installées
bundle list

# Voir les gems obsolètes
bundle outdated
```

---

## 🐘 PostgreSQL

```bash
# Démarrer PostgreSQL
sudo service postgresql start

# Arrêter PostgreSQL
sudo service postgresql stop

# Redémarrer PostgreSQL
sudo service postgresql restart

# Voir le statut
sudo service postgresql status

# Se connecter à PostgreSQL en ligne de commande
psql -U easymeal -d easymeal_development
```

---

## 🔧 Maintenance

```bash
# Vérifier que tout fonctionne
bin/rails db:prepare
bundle exec rspec
bundle exec brakeman

# Mettre à jour les gems de sécurité
bundle update --conservative

# Nettoyer le projet
bin/rails log:clear
bin/rails tmp:clear
rm -rf tmp/cache/*
```

---

## 🆘 Dépannage

### Le serveur ne démarre pas

```bash
# Vérifier qu'aucun serveur ne tourne déjà
lsof -i :3000
# Si un processus existe, le tuer :
kill -9 <PID>

# Redémarrer le serveur
bin/rails server
```

### Problème de gems

```bash
# Réinstaller toutes les gems
rm -rf vendor/bundle
bundle install
```

### Problème de base de données

```bash
# Vérifier que PostgreSQL tourne
sudo service postgresql status

# Réinitialiser complètement la base
bin/rails db:drop
bin/rails db:create
bin/rails db:migrate
bin/rails db:seed
```

### Annuler des modifications Git accidentelles

```bash
# Revenir à l'état du dernier commit (ATTENTION : perte définitive)
git reset --hard HEAD

# Récupérer un fichier supprimé
git checkout HEAD -- chemin/vers/fichier.rb
```

### Problème de push SourceTree (clé SSH)

Si le push dans SourceTree bloque à cause de SSH :

```bash
# Passer le dépôt en HTTPS (à faire une seule fois)
git remote set-url origin https://github.com/Caroline-B75/EasyMeal.git
```

Ensuite, SourceTree te demandera ton Personal Access Token GitHub.

---

## 📌 Raccourcis utiles

```bash
# Alias Git pratiques (à ajouter dans ~/.bashrc)
alias gs='git status'
alias gl='git log --oneline --graph --decorate'
alias gco='git checkout'
alias gpl='git pull'

# Alias Rails
alias rs='bin/rails server'
alias rc='bin/rails console'
alias rr='bin/rails routes'

# Alias merge rapide (sans nano)
alias gmerge='git merge --no-ff'
# Utilisation : gmerge ma-branche -m "Merge branch 'ma-branche' - Description"
```

/////////////// SCORE DE QUALITÉ DE CODE ///////////////

# ⭐ SCORE GLOBAL + rapport HTML (ouvre tmp/rubycritic/overview.html)

bundle exec rubycritic app --no-browser
explorer.exe "C:\Caroline\easymeal\tmp\rubycritic\overview.html"

# 🏗️ Bonnes pratiques Rails spécifiques

bundle exec rails_best_practices .

# 🎨 Style, complexité, conventions Ruby/Rails

bundle exec rubocop

# 🔒 Sécurité

bundle exec brakeman -q

---

# ☁️ Mise en ligne sur Scalingo

L'application tourne sur **https://easymeal.osc-fr1.scalingo.io**.
Tableau de bord : [dashboard.scalingo.com](https://dashboard.scalingo.com) → app `easymeal`.

## 🧭 Le principe, en trois phrases

1. `git push scalingo main` envoie le code : Scalingo **construit** l'image (bundle install, précompilation des assets).
2. Avant de mettre la nouvelle version en ligne, il lance le **hook `postdeploy`** défini dans le `Procfile` : les migrations, puis la resynchronisation du catalogue d'ingrédients.
3. Si le hook réussit → la nouvelle version passe en ligne. **S'il échoue → l'ancienne version continue de tourner**, et rien n'est cassé.

> `git push origin main` envoie sur GitHub (sauvegarde + historique).
> `git push scalingo main` déclenche la mise en ligne. **Les deux sont indépendants** : pousser sur GitHub ne déploie rien.

## ⚡ Que faire selon ce que j'ai changé

| J'ai modifié… | Ce que je fais | Pourquoi |
|---|---|---|
| Vues, CSS, JS, contrôleurs, helpers | `push` | rien d'autre à faire |
| Un modèle sans nouvelle colonne (validation, méthode, scope) | `push` | pas de changement de structure |
| **Une migration** (nouvel attribut, nouvelle table) | `push` | le hook lance `db:migrate` tout seul |
| **`db/seeds/data/ingredients.yml`** | `push` | le hook resynchronise le catalogue |
| Le `Gemfile` | `push` | `bundle install` tourne à la construction |
| `db/seeds/tags.rb` ou `recipes.rb` | commande manuelle (CLI) | hors du hook, volontairement |
| Une clé d'API, un mot de passe | onglet **Environment** | jamais dans le code |

**Le déploiement ordinaire, dans tous les cas :**

```bash
git push origin main      # sauvegarde sur GitHub
git push scalingo main    # met en ligne
```

Puis onglet **Deploy** pour suivre. Un déploiement prend 1 à 3 minutes.

## 🗄️ J'ai ajouté un attribut à un modèle

Rien de plus que le déploiement ordinaire : la migration part avec le code et le hook l'applique **avant** que la nouvelle version reçoive du trafic. C'est justement ce qui évite qu'un code neuf s'adresse à une colonne qui n'existe pas encore.

**Deux règles à ne jamais enfreindre :**

- **Ne jamais modifier une migration déjà déployée.** Elle a déjà tourné en production, Rails ne la rejouera pas. Pour corriger, on écrit une *nouvelle* migration.
- **Supprimer ou renommer une colonne se fait en deux déploiements.** Sinon, pendant les quelques secondes de bascule, l'ancien code cherche une colonne que la migration vient d'effacer.
  1. Premier déploiement : le code cesse d'utiliser la colonne.
  2. Second déploiement : la migration la supprime.

  Ajouter une colonne, à l'inverse, ne pose jamais ce problème : personne ne s'en sert encore.

## 🥕 J'ai changé le catalogue d'ingrédients

Le fichier `db/seeds/data/ingredients.yml` est la **source de vérité** du catalogue. À chaque déploiement, le hook le rejoue et met la base en accord avec lui.

**Ce que ça implique concrètement :**

| Situation | Ce qui se passe |
|---|---|
| J'ai corrigé un poids dans le YAML | il part en production au prochain déploiement ✅ |
| J'ai corrigé un poids **dans l'application en ligne** | il sera **écrasé** au prochain déploiement ⚠️ |
| J'ai créé un ingrédient à la volée depuis une recette | il n'est **jamais touché** (absent du YAML) ✅ |
| J'ai ajouté un nom à la liste `retired:` du YAML | il est supprimé, sauf s'il est encore utilisé par une recette |

👉 **Règle à retenir : les corrections durables du catalogue se font dans le YAML, pas dans l'application en ligne.**

**Le cas du conflit.** Si un ingrédient de la production a un groupe d'unités différent de celui du YAML *et* qu'il est déjà utilisé dans une recette, la base refuse de le changer — sinon les quantités déjà saisies deviendraient fausses. La seed le **signale et continue** :

```
⚠️  « Nom de l'ingrédient » n'a pas pu être mis à jour : Groupe d'unités ne peut plus changer…
✅ 586 ingrédients en base (0 créés, 242 mis à jour, 0 retirés).
⚠️  1 ingrédient(s) laissés en l'état — voir les avertissements ci-dessus.
```

Le déploiement réussit quand même. Pour régler le conflit, il faut ouvrir la recette concernée et décider à la main — aucun script ne peut trancher ça.

## 🔐 J'ai besoin d'ajouter ou changer une clé

Onglet **Environment** → ajouter ou modifier la variable → l'application redémarre.
**Jamais dans le code**, jamais dans un commit.

Les variables actuelles : `RAILS_MASTER_KEY`, `DATABASE_URL`, `ANTHROPIC_API_KEY`, `CLOUDINARY_*`, `SMTP_*`, `MAILER_FROM`, `APP_HOST`.

## 🔥 Le déploiement a échoué

**D'abord, respire : ton site tourne toujours.** Un déploiement raté ne met jamais en ligne la version cassée.

1. Onglet **Deploy** → ouvrir le déploiement en échec → lire les logs **de bas en haut**.
2. Chercher la ligne qui commence par un nom d'erreur, du genre `ActiveRecord::RecordInvalid:` ou `NoMethodError:`, suivie du message. C'est elle qui compte, pas la pile de lignes `from /app/vendor/...` qui suit.
3. Ignorer les lignes préfixées `W,` ou `WARN` : ce sont des avertissements, jamais la cause d'un échec.

**Deux types d'échec :**

| Message | Signification |
|---|---|
| `Postdeploy hook failed` | le code est bon, mais la migration ou la seed a planté |
| erreur pendant `Compiling`/`assets:precompile` | le code ne construit pas (erreur de syntaxe, gem manquante) |

**Revenir en arrière** si besoin : il n'y a pas de bouton « rollback ». On repousse un commit antérieur.

```bash
git log --oneline -5                    # repérer le dernier commit qui marchait
git push scalingo <hash-du-commit>:main # le remettre en ligne
```

⚠️ **Le code revient en arrière, pas la base de données.** Une migration déjà appliquée le reste. Si elle a supprimé une colonne, l'ancien code ne la retrouvera pas — d'où la règle des deux déploiements plus haut.

## 📋 Voir ce qui se passe en production

Onglet **Logs** du tableau de bord : les erreurs de l'application en direct (les fameuses 500).
Onglet **Metrics** : mémoire et temps de réponse.
Onglet **Activity** : qui a déployé quoi, et quand.

## 🔧 La CLI Scalingo (pour aller plus loin)

Tout ce qui précède se fait sans elle. Elle devient nécessaire pour **lancer une commande ponctuelle sur la production** — c'est le seul moyen, le tableau de bord ne le permet pas.

Installation : [doc.scalingo.com/cli](https://doc.scalingo.com/cli), puis `scalingo login`.

```bash
# Une console Rails sur la production (⚠️ vraies données)
scalingo --app easymeal run rails console

# Resynchroniser le catalogue sans attendre un déploiement
scalingo --app easymeal run rails runner 'load Rails.root.join("db/seeds/ingredients.rb").to_s'

# Les autres seeds (tags, recettes de démonstration)
scalingo --app easymeal run rails runner 'load Rails.root.join("db/seeds/tags.rb").to_s'

# Les logs en direct
scalingo --app easymeal logs --follow

# Redémarrer l'application
scalingo --app easymeal restart
```

## 💾 Sauvegardes de la base

PostgreSQL est un *addon* : onglet **Overview** → carte **Addons** → **Dashboard** à côté de PostgreSQL.
On y trouve les sauvegardes automatiques et de quoi en déclencher une à la main — à faire **avant toute opération risquée** (migration destructive, gros re-seed).

## ✅ Avant chaque mise en ligne

```bash
bundle exec rspec                            # la suite doit être verte
bundle exec rubocop                          # zéro remarque
bundle exec bundler-audit check --update     # aucune faille connue
```
