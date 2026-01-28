# 🚀 Commandes EasyMeal - Guide rapide

## 📂 Ouvrir et démarrer le projet

```bash
# 1. Aller dans le projet
cd /mnt/c/Caroline/easymeal

# 2. Activer Ruby avec RVM
rvm use 3.2.3@easymeal --create

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
rvm use 3.2.3@easymeal --create
rails c

-> pour afficher "joliment" les attributs il faut mettre "ap" avant la commande. Ex:
ap User.first

→ Application accessible sur **http://localhost:3000**

---

## 🔄 Workflow Git complet (SourceTree + Console)

### ✨ Workflow en 4 étapes

#### **ÉTAPE 1 : Créer une nouvelle branche**

**Dans SourceTree :**

1. Assurez-vous d'être sur la branche `main` (double-clic sur `main` dans la liste des branches)
2. Cliquez sur le bouton **Branche** (en haut)
3. Nommez votre branche (ex: `feature/recipes`, `fix/login-bug`)
4. Cochez **Créer une nouvelle branche**
5. Cliquez sur **Créer une branche**

**Alternative en console :**

```bash
git checkout main
git checkout -b feature/nom-de-ma-fonctionnalite
```

---

#### **ÉTAPE 2 : Faire des commits**

**Dans SourceTree (recommandé) :**

**Pour commiter TOUS les fichiers modifiés :**

1. Dans l'onglet **État des fichiers**, cochez la case tout en haut (à côté de "Fichiers non indexés")
2. Tous les fichiers passent dans "Fichiers indexés"
3. En bas, écrivez votre message de commit (ex: `feat: ajout du modèle Recipe`)
4. Cliquez sur **Commit**

**Pour commiter QUELQUES fichiers seulement :**

1. Dans "Fichiers non indexés", cochez **uniquement** les fichiers que vous voulez commiter
2. Ils passent dans "Fichiers indexés"
3. En bas, écrivez votre message de commit
4. Cliquez sur **Commit**

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

**→ Répétez cette étape autant de fois que nécessaire pendant votre développement**

---

#### **ÉTAPE 3 : Merger dans main et pousser sur GitHub**

**En console (obligatoire pour éviter l'éditeur nano) :**

```bash
# 1. Aller sur main
git checkout main

# 2. Merger votre branche (remplacez "nom-branche" par le nom de votre branche)
git merge --no-ff nom-branche -m "Merge branch 'nom-branche' - Description courte"

# 3. Pousser vers GitHub
git push origin main
```

**Exemple concret :**

```bash
git checkout main
git merge --no-ff feature/recipes -m "Merge branch 'feature/recipes' - Ajout modèle Recipe"
git push origin main
```

---

#### **ÉTAPE 4 : Supprimer la branche**

**En console (recommandé) :**

```bash
# Supprimer la branche locale
git branch -d nom-branche
```

**Dans SourceTree :**

1. Faites un clic droit sur votre branche (dans la liste des branches à gauche)
2. Sélectionnez **Supprimer la branche**
3. Confirmez

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

Ensuite, SourceTree vous demandera votre Personal Access Token GitHub.

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
