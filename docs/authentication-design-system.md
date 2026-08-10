# Système d'Authentification EasyMeal

## 📋 Vue d'ensemble

Ce document explique le système d'authentification moderne implémenté pour EasyMeal, incluant les vues personnalisées Devise et le design system.

## 🎨 Design System

### Couleurs Principales (Slate Craft Premium)

- **Primary**: `#1C1917` (Anthracite)
- **Primary Hover**: `#44403C`
- **Background**: `#F8F7F4` (Blanc chaud)
- **Accent**: `#FBBF24` (Ambre — étoiles et saison uniquement)

### Composants

#### Pages d'Authentification

- ✅ **Inscription** (`/users/sign_up`)
- ✅ **Connexion** (`/users/sign_in`)
- ✅ **Mot de passe oublié** (`/users/password/new`)

### Champs du Formulaire d'Inscription

1. **Username** - Nom d'utilisateur unique
2. **First Name** - Prénom
3. **Last Name** - Nom
4. **Email** - Adresse email
5. **Password** - Mot de passe (min. 6 caractères)
6. **Password Confirmation** - Confirmation du mot de passe

## 📁 Structure des Fichiers

```
app/
├── views/
│   ├── devise/
│   │   ├── registrations/
│   │   │   └── new.html.erb          # Page d'inscription
│   │   ├── sessions/
│   │   │   └── new.html.erb          # Page de connexion
│   │   ├── passwords/
│   │   │   └── new.html.erb          # Mot de passe oublié
│   │   └── shared/
│   │       └── _links.html.erb       # Liens de navigation
│   └── shared/
│       └── _form_field.html.erb      # Composant de champ réutilisable
├── assets/
│   └── stylesheets/
│       └── authentication.css        # Styles pour l'authentification
└── controllers/
    └── application_controller.rb     # Configuration Devise parameters
```

## 🔧 Configuration

### Paramètres Devise Autorisés

Dans `application_controller.rb`, les paramètres suivants sont autorisés :

```ruby
devise_parameter_sanitizer.permit(:sign_up, keys: [:username, :first_name, :last_name])
devise_parameter_sanitizer.permit(:account_update, keys: [:username, :first_name, :last_name])
```

### Traductions

Les traductions sont configurées dans :

- `config/locales/simple_form.fr.yml` - Français
- `config/locales/simple_form.en.yml` - Anglais

## 🎯 Fonctionnement de Devise

### Comment les vues sont-elles affichées ?

1. **Par défaut** : Devise utilise ses propres vues intégrées au gem
2. **Personnalisé** : En créant des fichiers dans `app/views/devise/`, Rails utilise automatiquement ces vues au lieu de celles du gem
3. **Routes** : Configurées via `devise_for :users` dans `routes.rb`

### Routes Principales

- `GET /users/sign_up` → `devise/registrations#new`
- `POST /users` → `devise/registrations#create`
- `GET /users/sign_in` → `devise/sessions#new`
- `POST /users/sign_in` → `devise/sessions#create`

## 💅 Classes CSS Réutilisables

### Container & Cards

```html
<div class="auth-container">
  <div class="auth-card">
    <!-- Contenu -->
  </div>
</div>
```

### En-têtes

```html
<div class="auth-header">
  <h1 class="auth-title">Titre</h1>
  <p class="auth-subtitle">Sous-titre</p>
</div>
```

### Formulaires

```html
<div class="form-group">
  <label class="form-label">Label</label>
  <input class="form-input" type="text" placeholder="Placeholder" />
</div>
```

### Boutons

```html
<button class="btn btn-primary btn-large">Action</button>
```

### Grille de Formulaire

```html
<div class="form-row">
  <div class="form-group form-group-half">...</div>
  <div class="form-group form-group-half">...</div>
</div>
```

## 🔄 Composants Réutilisables

### Champ de Formulaire Personnalisé

```erb
<%= render 'shared/form_field',
    form: f,
    field: :email,
    type: :email_field,
    required: true,
    placeholder: 'votre.email@exemple.com',
    autocomplete: 'email',
    label: 'Email' %>
```

## 📱 Responsive Design

Le design est entièrement responsive avec des breakpoints à :

- **640px** : Ajustements pour tablettes
- **480px** : Optimisation mobile

## ♿ Accessibilité

- Focus visible pour la navigation au clavier
- Labels appropriés pour les lecteurs d'écran
- Contrastes de couleurs conformes WCAG
- Support pour `prefers-reduced-motion`

## 🚀 Améliorations Futures

- [ ] Ajout d'un indicateur de force du mot de passe
- [ ] Validation en temps réel des champs
- [ ] Animation de transition entre les pages
- [ ] Support du mode sombre
- [ ] Authentification OAuth (Google, Facebook, etc.)

## 📝 Notes de Développement

### SimpleForm vs Form Builder Standard

Le projet utilise **SimpleForm** pour une meilleure intégration avec les validations et les traductions. Les classes CSS sont appliquées via les options `input_html`, `label_html`, et `wrapper_html`.

### Variables CSS Personnalisables

Toutes les couleurs et espacements sont définis comme variables CSS dans `:root` pour une personnalisation facile :

```css
:root {
  --primary-color: #10b981;
  --primary-hover: #059669;
  --radius-md: 0.5rem;
  /* ... */
}
```

## 🐛 Dépannage

### Les styles ne s'appliquent pas

Vérifiez que `authentication.css` est importé dans votre manifest (`app/assets/config/manifest.js`) ou dans `application.css`.

### Les champs username, first_name, last_name ne sont pas sauvegardés

Assurez-vous que `configure_permitted_parameters` est bien défini dans `application_controller.rb`.

### Messages d'erreur en anglais

Vérifiez la locale par défaut dans `config/application.rb` ou `config/initializers/devise.rb`.
