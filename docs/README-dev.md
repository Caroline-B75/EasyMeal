# 🧭 Guide de démarrage — EasyMeal (environnement de développement)

Ce document récapitule toutes les commandes et actions nécessaires pour travailler sur le projet **EasyMeal** (Rails 7.2 + PostgreSQL + Importmap + Turbo + Stimulus + Devise + Pundit + RSpec).

---

## ⚙️ 1. Ouvrir le projet

```bash
cd /mnt/c/Caroline/easymeal
git status
💎 2. Activer Ruby avec RVM
bash
Copier le code
rvm use 3.2.3@easymeal --create
bundle install
(Le gemset @easymeal permet d’isoler les gems de ce projet.)

🗃️ 3. Démarrer PostgreSQL et préparer la base
bash
Copier le code
sudo service postgresql start
bin/rails db:prepare
.env doit contenir les variables suivantes (jamais commitées) :

dotenv
Copier le code
POSTGRES_HOST=localhost
POSTGRES_PORT=5432
POSTGRES_USER=easymeal
POSTGRES_PASSWORD=********
POSTGRES_DB_DEV=easymeal_development
POSTGRES_DB_TEST=easymeal_test
🧑‍💻 4. Lancer le serveur
bash
Copier le code
bin/rails server
→ http://localhost:3000

🌿 5. Créer une nouvelle branche à partir de main
bash
Copier le code
git checkout main
git pull origin main
git checkout -b feature/mon-sujet
💾 6. Commit et push
bash
Copier le code
git add .
git commit -m "feat: mon sujet (résumé clair)"
git push -u origin feature/mon-sujet
🔀 7. Fusionner la branche dans main
Option A — via Pull Request (recommandé)
Créer la PR sur GitHub : compare feature/mon-sujet → base main

Merger la PR

Mettre à jour localement :

bash
Copier le code
git checkout main
git pull origin main
git branch -d feature/mon-sujet
git push origin --delete feature/mon-sujet
Option B — en local
bash
Copier le code
git checkout main
git pull origin main
git merge --no-ff feature/mon-sujet
git push origin main
git branch -d feature/mon-sujet
git push origin --delete feature/mon-sujet
🧰 8. Commandes Rails utiles
bash
Copier le code
bin/rails about               # Infos env Rails
bin/rails routes              # Liste des routes
bin/rails console             # Console Rails (IRB)
bin/rails db:migrate          # Appliquer les migrations
bin/rails db:rollback STEP=1  # Revenir en arrière
bin/rails g model Recipe name:string   # Exemple : générer un modèle
bin/rails g controller Recipes index   # Exemple : générer un contrôleur
🧪 9. Tests & qualité
bash
Copier le code
bundle exec rspec             # Lancer les tests
bundle exec brakeman          # Scan sécurité
bundle exec bundler-audit     # Audit des dépendances
⚡ 10. Commandes Git pratiques
bash
Copier le code
git log --oneline --graph --decorate --all
git diff
git restore --staged <fichier>
git stash push -m "work in progress"
git stash pop
🚫 11. Fichiers à ne jamais committer
bash
Copier le code
.env
/config/master.key
/config/credentials/*.key
/log/*
/tmp/*
/storage/*
!/storage/.keep
node_modules/
✅ 12. Vérification rapide
bash
Copier le code
sudo service postgresql start
rvm use 3.2.3@easymeal
bundle install
bin/rails db:prepare
bin/rails server
→ Application accessible sur http://localhost:3000

```
