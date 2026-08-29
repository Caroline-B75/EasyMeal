# 📚 Comment Fonctionne l'Affichage des Vues Devise ?

## ❓ La Question

> "Je ne vois pas la vue sign_up dans les fichiers de mon projet... Comment fonctionne l'affichage de la vue users/sign_up ?"

## 💡 La Réponse

### Principe de Base

**Devise** est un gem Ruby qui gère l'authentification. Par défaut, toutes ses vues (inscription, connexion, etc.) sont **intégrées au gem lui-même** et ne sont **PAS copiées** dans ton projet.

### 🔍 Où Sont les Vues par Défaut ?

Les vues Devise se trouvent dans le gem installé, généralement à :

```
C:\Users\[VotreNom]\.rbenv\versions\[version-ruby]\lib\ruby\gems\[version]\gems\devise-[version]\app\views\devise\
```

Ou si tu utilises bundler :

```
[ton-projet]\vendor\bundle\ruby\[version]\gems\devise-[version]\app\views\
```

### 🎯 Comment Rails Trouve les Vues ?

Quand tu accèdes à `/users/sign_up`, Rails suit ce processus :

```
1. Requête HTTP : GET /users/sign_up
           ↓
2. Routes (config/routes.rb)
   devise_for :users
   → Route vers Devise::RegistrationsController#new
           ↓
3. Contrôleur Devise
   Cherche la vue à afficher
           ↓
4. Recherche de Vue (dans cet ordre)
   ✓ app/views/devise/registrations/new.html.erb  ← Ton projet
   ✗ Si absent, cherche dans le gem Devise
           ↓
5. Affichage de la Vue
```

### 📝 Hiérarchie de Recherche

Rails cherche les vues dans cet ordre de priorité :

```
1. app/views/devise/registrations/new.html.erb    (Ton projet - PRIORITÉ)
2. [gem-devise]/app/views/devise/registrations/new.html.erb  (Gem)
```

**Si le fichier existe dans ton projet → Il remplace celui du gem !**

---

## 🛠️ Trois Méthodes pour Personnaliser

### Méthode 1 : Générer Toutes les Vues (Ancienne méthode)

```bash
rails generate devise:views
```

**Résultat :** Copie TOUTES les vues Devise dans `app/views/devise/`

**Avantages :**

- ✅ Contrôle total sur toutes les vues

**Inconvénients :**

- ❌ Beaucoup de fichiers (15-20 vues)
- ❌ Maintenance complexe lors des mises à jour Devise

### Méthode 2 : Créer Manuellement les Vues Nécessaires (Notre approche ✨)

```
Créer uniquement :
app/views/devise/registrations/new.html.erb
app/views/devise/sessions/new.html.erb
```

**Avantages :**

- ✅ Contrôle précis sur les vues importantes
- ✅ Moins de fichiers à maintenir
- ✅ Les autres vues utilisent encore le gem (confirmations, etc.)

**Inconvénients :**

- ❌ Nécessite de créer chaque vue une par une

### Méthode 3 : Utiliser les Vues du Gem (Par défaut)

Ne rien faire, laisser Devise gérer.

**Avantages :**

- ✅ Aucun fichier à maintenir
- ✅ Mises à jour automatiques avec Devise

**Inconvénients :**

- ❌ Design basique
- ❌ Pas de personnalisation

---

## 🗺️ Cartographie Complète des Vues Devise

### Pages d'Inscription (Registrations)

```
app/views/devise/registrations/
├── new.html.erb           → /users/sign_up (Formulaire d'inscription)
├── edit.html.erb          → /users/edit (Modifier le compte)
└── cancel.html.erb        → Annuler l'inscription
```

### Pages de Connexion (Sessions)

```
app/views/devise/sessions/
└── new.html.erb           → /users/sign_in (Formulaire de connexion)
```

### Pages de Mot de Passe (Passwords)

```
app/views/devise/passwords/
├── new.html.erb           → /users/password/new (Demande de réinitialisation)
└── edit.html.erb          → /users/password/edit (Nouveau mot de passe)
```

### Pages de Confirmation (Confirmations)

```
app/views/devise/confirmations/
└── new.html.erb           → /users/confirmation/new (Renvoyer email)
```

### Pages de Déverrouillage (Unlocks)

```
app/views/devise/unlocks/
└── new.html.erb           → /users/unlock/new (Déverrouiller le compte)
```

### Partials Partagés

```
app/views/devise/shared/
├── _links.html.erb        → Liens de navigation (S'inscrire, Se connecter, etc.)
└── _error_messages.html.erb → Messages d'erreur
```

---

## 🎯 Notre Implémentation

### Ce Que Nous Avons Créé

```
app/views/devise/
├── registrations/
│   └── new.html.erb          ✨ CRÉÉ - Page d'inscription moderne
├── sessions/
│   └── new.html.erb          ✨ CRÉÉ - Page de connexion moderne
├── passwords/
│   └── new.html.erb          ✨ CRÉÉ - Mot de passe oublié moderne
└── shared/
    └── _links.html.erb       ✨ CRÉÉ - Navigation traduite
```

### Routes Correspondantes

| URL                       | Vue Utilisée                        | Contrôleur                             |
| ------------------------- | ----------------------------------- | -------------------------------------- |
| `GET /users/sign_up`      | `devise/registrations/new.html.erb` | Devise::RegistrationsController#new    |
| `POST /users`             | (traitement)                        | Devise::RegistrationsController#create |
| `GET /users/sign_in`      | `devise/sessions/new.html.erb`      | Devise::SessionsController#new         |
| `POST /users/sign_in`     | (traitement)                        | Devise::SessionsController#create      |
| `GET /users/password/new` | `devise/passwords/new.html.erb`     | Devise::PasswordsController#new        |

---

## 🔧 Configuration dans le Projet

### 1. Routes (`config/routes.rb`)

```ruby
devise_for :users
```

Cette ligne génère automatiquement toutes les routes :

```
         Prefix Verb   URI Pattern                    Controller#Action
new_user_session GET    /users/sign_in                devise/sessions#new
    user_session POST   /users/sign_in                devise/sessions#create
destroy_user_session DELETE /users/sign_out           devise/sessions#destroy
new_user_password GET    /users/password/new          devise/passwords#new
edit_user_password GET   /users/password/edit         devise/passwords#edit
     user_password PATCH  /users/password              devise/passwords#update
                   PUT    /users/password              devise/passwords#update
                   POST   /users/password              devise/passwords#create
cancel_user_registration GET /users/cancel             devise/registrations#cancel
new_user_registration GET    /users/sign_up            devise/registrations#new
edit_user_registration GET   /users/edit               devise/registrations#edit
     user_registration PATCH  /users                    devise/registrations#update
                   PUT    /users                        devise/registrations#update
                   DELETE /users                        devise/registrations#destroy
                   POST   /users                        devise/registrations#create
```

### 2. Modèle (`app/models/user.rb`)

```ruby
devise :database_authenticatable, :registerable,
       :recoverable, :rememberable, :validatable
```

Ces modules activent les fonctionnalités Devise.

### 3. Contrôleur (`app/controllers/application_controller.rb`)

```ruby
before_action :configure_permitted_parameters, if: :devise_controller?

def configure_permitted_parameters
  devise_parameter_sanitizer.permit(:sign_up, keys: [:username, :first_name, :last_name])
end
```

Cette configuration permet d'ajouter des champs personnalisés.

---

## 🎨 Le Flux Complet

### Exemple : Création d'un Compte

```
1. Utilisateur visite /users/sign_up
           ↓
2. Rails → Routes → Devise::RegistrationsController#new
           ↓
3. Contrôleur → Cherche la vue
           ↓
4. Trouve app/views/devise/registrations/new.html.erb
   (notre vue personnalisée ✨)
           ↓
5. Affiche le formulaire avec SimpleForm
           ↓
6. Utilisateur remplit et soumet le formulaire
           ↓
7. POST /users → Devise::RegistrationsController#create
           ↓
8. Devise valide les données (validations du modèle User)
           ↓
9. Si valide → Sauvegarde dans la base de données
           ↓
10. Devise connecte automatiquement l'utilisateur
           ↓
11. Redirection vers root_path (page d'accueil)
```

---

## 📊 Comparaison : Avant vs Après

### AVANT (Vue du Gem)

```html
<!-- Vue basique générée par Devise -->
<h2>Sign up</h2>

<%= form_for(resource, as: resource_name, url: registration_path(resource_name))
do |f| %> <%= f.email_field :email %> <%= f.password_field :password %> <%=
f.submit "Sign up" %> <% end %>
```

### APRÈS (Notre Vue Moderne) ✨

```html
<!-- Vue personnalisée avec design moderne -->
<div class="auth-container">
  <div class="auth-card">
    <h1 class="auth-title">Créer un compte</h1>
    <p class="auth-subtitle">Rejoins EasyMeal...</p>

    <%= simple_form_for(...) do |f| %>
    <!-- 6 champs modernes avec design cohérent -->
    <% end %>
  </div>
</div>
```

---

## 🎓 Points Clés à Retenir

1. **Les vues Devise sont dans le gem** par défaut
2. **Créer un fichier dans `app/views/devise/`** remplace automatiquement la vue du gem
3. **Pas besoin de générer toutes les vues**, seulement celles à personnaliser
4. **Rails cherche d'abord dans ton projet**, puis dans le gem
5. **La configuration se fait dans `application_controller.rb`** pour les nouveaux champs

---

## 🚀 Conclusion

Maintenant tu sais :

- ✅ Où sont les vues Devise par défaut
- ✅ Comment Rails les trouve
- ✅ Comment les personnaliser
- ✅ Pourquoi notre approche fonctionne

**Et tu as maintenant une magnifique page d'inscription moderne ! 🎉**

---

_Documentation créée pour EasyMeal - Janvier 2026_
