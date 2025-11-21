# 🚀 Commandes EasyMeal - Guide rapide

## 📂 Ouvrir et démarrer le projet

```bash
# 1. Aller dans le projet
cd /mnt/c/Caroline/easymeal

# 2. Activer Ruby avec RVM
rvm use 3.2.3@easymeal --create

# 3. Installer/mettre à jour les gems
bundle install

# 4. Démarrer PostgreSQL
sudo service postgresql start

# 5. Préparer la base de données
bin/rails db:prepare

# 6. Lancer le serveur
bin/rails server
```

→ Application accessible sur **http://localhost:3000**

---

## 🌿 Git - Gestion des branches

### Créer une nouvelle branche

```bash
# 1. Se mettre sur main et récupérer les dernières modifications
git checkout main
git pull origin main

# 2. Créer et basculer sur une nouvelle branche
git checkout -b feature/nom-de-ma-fonctionnalite
```

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

```bash
git checkout nom-de-la-branche
```

### Supprimer une branche

```bash
# Supprimer une branche locale (après merge)
git branch -d nom-de-la-branche

# Forcer la suppression (si pas mergée)
git branch -D nom-de-la-branche

# Supprimer une branche distante
git push origin --delete nom-de-la-branche
```

---

## 💾 Git - Commits et push

### Voir l'état des fichiers

```bash
# Voir les fichiers modifiés
git status

# Voir les différences détaillées
git diff

# Voir les différences des fichiers stagés
git diff --staged
```

### Faire un commit

```bash
# 1. Ajouter tous les fichiers modifiés
git add .

# OU ajouter des fichiers spécifiques
git add chemin/vers/fichier.rb

# 2. Committer avec un message
git commit -m "feat: description claire de la modification"

# 3. Pousser vers GitHub
git push

# OU pour la première fois sur une nouvelle branche
git push -u origin feature/nom-de-ma-branche
```

### Messages de commit conventionnels

```bash
git commit -m "feat: ajout du modèle Recipe"        # Nouvelle fonctionnalité
git commit -m "fix: correction du bug sur la route" # Correction de bug
git commit -m "refactor: amélioration du service"   # Refactoring
git commit -m "test: ajout des specs Recipe"        # Tests
git commit -m "docs: mise à jour du README"         # Documentation
git commit -m "style: formatage du code"            # Style/formatage
git commit -m "chore: mise à jour des gems"         # Tâches diverses
```

### Annuler des modifications

```bash
# Annuler les modifications d'un fichier (avant add)
git restore chemin/vers/fichier.rb

# Retirer un fichier du staging (après add, avant commit)
git restore --staged chemin/vers/fichier.rb

# Annuler le dernier commit (garde les modifications)
git reset --soft HEAD~1

# Annuler le dernier commit (supprime les modifications)
git reset --hard HEAD~1
```

---

## 🔀 Git - Merge et Pull Requests

### Option A : Merge via Pull Request GitHub (recommandé)

```bash
# 1. Pousser ta branche
git push -u origin feature/ma-branche

# 2. Aller sur GitHub et créer une Pull Request
# 3. Merger la PR sur GitHub
# 4. Mettre à jour localement
git checkout main
git pull origin main

# 5. Supprimer la branche locale
git branch -d feature/ma-branche

# 6. Supprimer la branche distante (si pas fait automatiquement)
git push origin --delete feature/ma-branche
```

### Option B : Merge en local

```bash
# 1. Se mettre sur main et récupérer les dernières modifs
git checkout main
git pull origin main

# 2. Merger la branche
git merge --no-ff feature/ma-branche

# 3. Pousser sur GitHub
git push origin main

# 4. Supprimer la branche
git branch -d feature/ma-branche
git push origin --delete feature/ma-branche
```

---

## 📜 Git - Historique et informations

```bash
# Voir l'historique des commits
git log

# Historique compact et graphique
git log --oneline --graph --decorate --all

# Voir les 5 derniers commits
git log -5 --oneline

# Voir qui a modifié quoi dans un fichier
git blame chemin/vers/fichier.rb

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

---

## 📌 Raccourcis utiles

```bash
# Alias Git pratiques (à ajouter dans ~/.bashrc)
alias gs='git status'
alias ga='git add .'
alias gc='git commit -m'
alias gp='git push'
alias gl='git log --oneline --graph --decorate'
alias gco='git checkout'
alias gpl='git pull'

# Alias Rails
alias rs='bin/rails server'
alias rc='bin/rails console'
alias rr='bin/rails routes'
```

---

✨ **Bon développement !**
