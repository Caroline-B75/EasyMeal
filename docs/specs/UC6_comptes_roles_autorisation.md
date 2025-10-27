UC6 — Comptes, rôles & autorisations (Devise + Pundit)
Version : 1.0
Contexte : Rails 7.2, Devise, Pundit, Haml, Turbo, RSpec.
Prérequis : modèles de base (User), Pundit installé, flash/partials en place.

---

0. Objectif métier
   • Permettre aux utilisateurs de créer un compte, se connecter et gérer quelques préférences (régime par défaut, nombre de personnes par défaut…).
   • Distinguer deux rôles :
   o admin : gestion du catalogue (ex. création d’Ingredients via pop-up UC3 “switch ON”), actions d’admin.
   o user : usage normal (menus, liste de courses, favoris, notes, ajouts manual).
   • Sécuriser l’accès aux ressources via Pundit (lecture/écriture selon propriétaire & rôle).

---

1. Portée (in / out)
   Inclus
   • Authentification Devise : inscription, login/logout, reset password, remember me.
   • (Option recommandé) Confirmable (email) pour limiter le spam.
   • (Option) Lockable après X échecs (anti-bruteforce).
   • Rôles : User#admin:boolean (par défaut false).
   • Préférences utilisateur (profil) :
   o default_diet (enum aligné avec UC1),
   o default_people (integer ≥1),
   o (option) locale, timezone.
   • Pundit policies : Menu, MenuRecipe (update_people), GroceryList/GroceryItem, Ingredient (create admin only), Recipe (publique), Review/Favorite (owner), etc.
   • Seeds : création d’un admin initial.
   Exclus (v1)
   • OAuth (Google/Apple…), double authentification, gestion RGPD avancée.

---

2. Modèle & migrations
   User
   Champs proposés :
   • Devise (classique) : email, encrypted_password, reset_password_token, etc.
   • Rôle : admin:boolean (def: false, null: false, index).
   • Préférences :
   o default_diet:integer (enum, def: omnivore par ex.),
   o default_people:integer (def: 4, min 1, null: false),
   o locale:string (ex. “fr”), timezone:string (ex. “Europe/Paris”) — optionnels.
   Validations :
   • default_people >= 1.
   Enum :
   enum default_diet: { omnivore: 0, vegetarien: 1, vegan: 2, pescetarien: 3 } # à caler avec UC1
   Seed admin

# db/seeds.rb

User.where(email: ENV['ADMIN_EMAIL']).first_or_create! do |u|
u.password = ENV['ADMIN_PASSWORD'] || SecureRandom.hex(16)
u.admin = true
u.default_diet = :omnivore
u.default_people = 4
end

---

3. Devise — modules & config
   Modules minimal v1 :
   • :database_authenticatable, :registerable, :recoverable, :rememberable, :validatable
   Options recommandées :
   • :confirmable (si l’email est en place),
   • :trackable (stats simples),
   • :lockable (X tentatives).
   Routes :
   devise_for :users
   Paramètres supplémentaires (strong params) pour le profil :
   • default_diet, default_people, locale, timezone.
   •

---

4. Pundit — Policies
   Principes
   • Owner-only pour les ressources liées à un menu/liste.
   • Admin-only pour la création d’Ingredients (catalogue).
   • Lecture des Recipe publique (sauf si tu veux restreindre aux connectés).
   Policies (exemples)
   MenuPolicy
   • show? → record.user_id == user.id
   • update? → idem
   • destroy? → idem
   • (archive plus tard UC7)
   MenuRecipePolicy
   • update_people? → propriétaire du menu.
   GroceryListPolicy / GroceryItemPolicy
   • show?/update?/destroy? → propriétaire du menu.
   IngredientPolicy
   • create?/update?/destroy? → user.admin?
   • index?/show? → true
   RecipePolicy
   • show? → true
   • (écriture catalogue recette : admin si tu veux)
   FavoriteRecipePolicy / ReviewPolicy
   • create?/update?/destroy? → record.user_id == user.id
   (pour create on construit record.user = user avant l’authorize)

---

5. Intégrations avec UC1–UC5
   • UC1 (génération) : si l’utilisateur est connecté, proposer par défaut diet = current_user.default_diet et number_of_people = current_user.default_people.
   • UC2 (personnalisation) : Pundit protège toutes les mutations (owner).
   • UC3 (liste) : création d’Ingredients via pop-up réservée admin (chemin C) ; chemins A & B accessibles à tous.
   • UC4 (fiche) : Favori / Note / Commentaires nécessitent current_user.
   • UC5 (catalogue) : “Ajouter au menu / draft” nécessite current_user + ownership (Pundit).

---

6. UX (pages & composants)
   • Devise views : Haml sobres, validations inline, liens: s’inscrire / mot de passe oublié.
   • Page “Mon profil” :
   o Email (non éditable v1 si confirmable),
   o default_diet (select), default_people (number min=1),
   o (option) locale, timezone,
   o Boutons : “Enregistrer”, “Changer mon mot de passe” (Devise), “Supprimer mon compte” (option v1).
   • Admin badge (si current_user.admin?) dans la navbar (discret).
   • Dans la pop-up UC3, si non-admin → désactiver le chemin “Créer un nouvel ingrédient” + tooltip “Réservé admin”.

---

7. TDD — Scénarios (Gherkin)
   Feature: Comptes & autorisations

Background:
Given un utilisateur "alice@example.com" (non admin)
And un utilisateur admin "admin@example.com"
And un menu appartenant à Alice

Scenario: Inscription et préférences
When je m'inscris avec email et mot de passe
And je renseigne "Régime: végétarien" et "Personnes par défaut: 4"
Then mon profil affiche ces préférences
And UC1 préremplit diet=végétarien et people=4

Scenario: Accès interdit au menu d'un autre
Given je suis connecté en tant que Alice
When j'essaie d'ouvrir un menu appartenant à un autre utilisateur
Then je vois une erreur d'autorisation (403/redirect)

Scenario: Mise à jour du nombre de personnes (menu)
Given je suis connecté en tant que Alice
When je modifie "menu_recipe #1" de 4 à 6 personnes
Then la mise à jour réussit
And un autre utilisateur ne peut pas faire la même action

Scenario: Pop-up "Créer un ingrédient" réservé admin
Given je suis connecté en tant que Alice (non admin)
When j'ouvre "Ajouter une course"
Then l'option "Créer un nouvel ingrédient" est désactivée avec un message "Réservé admin"
And je peux utiliser "Ajouter sans l'enregistrer"

Scenario: Admin crée un ingrédient
Given je suis connecté en tant que Admin
When j'ouvre "Ajouter une course" et choisis "Créer un nouvel ingrédient"
And je saisis les champs requis et valide
Then l'Ingredient est créé
And je peux l'ajouter à la liste

Scenario: Favori/Review protégés
Given je ne suis pas connecté
When je tente d'ajouter une recette en favori
Then je suis redirigé vers la connexion

---

8. Specs (exemples RSpec)
   Policies
   describe MenuPolicy do
   subject { described_class }
   let(:owner) { create(:user) }
   let(:other) { create(:user) }
   let(:menu) { create(:menu, user: owner) }

permissions :show?, :update?, :destroy? do
it "permet au propriétaire" do
expect(subject).to permit(owner, menu)
end
it "refuse aux autres" do
expect(subject).not_to permit(other, menu)
end
end
end

describe IngredientPolicy do
let(:admin) { create(:user, admin: true) }
let(:user) { create(:user) }
let(:ingredient) { build(:ingredient) }

permissions :create? do
it { expect(described_class).to permit(admin, ingredient) }
it { expect(described_class).not_to permit(user, ingredient) }
end
end
Controllers
• Devise registrations : accepte default_diet/default_people.
• Menus::MenusController#update_meal_people : interdit si !owner.
• GroceryItems#create_and_add_ingredient : interdit si !admin.

---

9. Routing
   devise_for :users

resource :profile, only: [:show, :edit, :update] # préférences user

# ou Users::ProfilesController si tu préfères

---

10. Checklist PO/QA
    • Inscription / login / reset OK.
    • Préférences user enregistrées, et pré-remplies dans UC1.
    • admin visible en seed et reconnu (badge discret).
    • Pundit bloque bien l’accès/écriture non autorisés.
    • Pop-up UC3 : Créer Ingredient visible & actif uniquement pour admin ; fallback “Ajouter sans l’enregistrer” pour les autres.
    • Tests Policy OK.

---

11. Notes pédagogiques
    • Moins de magie : centralise les règles d’accès dans Pundit — contrôleurs fins.
    • Préférences user = gros gain UX (moins de clics à chaque génération).
    • Commence sans confirmable si la messagerie n’est pas prête, tu l’activeras plus tard sans rework.
    • Pense à un seed admin simple + .env (dotenv-rails) pour mail & mdp.
