# Guide d'Amélioration Optionnelle du Layout

## Messages Flash Modernes

Pour un meilleur affichage des messages flash, tu peux modifier le layout.

### Option 1 : Remplacer les lignes 20-21 de `application.html.erb`

**Actuellement :**

```erb
<p class="notice"><%= notice %></p>
<p class="alert"><%= alert %></p>
```

**Remplacer par :**

```erb
<% if notice.present? || alert.present? %>
  <div class="flash-messages">
    <% if notice.present? %>
      <div class="flash-message notice"><%= notice %></div>
    <% end %>
    <% if alert.present? %>
      <div class="flash-message alert"><%= alert %></div>
    <% end %>
  </div>
<% end %>
```

### Option 2 : Créer un Partial

**Créer `app/views/shared/_flash_messages.html.erb` :**

```erb
<% if flash.any? %>
  <div class="flash-messages">
    <% flash.each do |type, message| %>
      <div class="flash-message <%= type %>">
        <%= message %>
      </div>
    <% end %>
  </div>
<% end %>
```

**Dans le layout, remplacer par :**

```erb
<%= render 'shared/flash_messages' %>
```

## Navigation Utilisateur

Pour une meilleure UX, tu peux aussi améliorer la navigation en créant un header.

**Créer `app/views/shared/_header.html.erb` :**

```erb
<header class="app-header">
  <div class="container">
    <div class="header-content">
      <h1 class="logo">
        <%= link_to "EasyMeal", root_path %>
      </h1>

      <nav class="user-nav">
        <% if user_signed_in? %>
          <span class="user-email">
            <%= current_user.username || current_user.email %>
          </span>
          <%= link_to "Se déconnecter",
                      destroy_user_session_path,
                      data: { turbo_method: :delete },
                      class: "btn-logout" %>
        <% else %>
          <%= link_to "Se connecter", new_user_session_path, class: "btn-link" %>
          <%= link_to "S'inscrire", new_user_registration_path, class: "btn-signup" %>
        <% end %>
      </nav>
    </div>
  </div>
</header>
```

**CSS pour le header (`app/assets/stylesheets/header.css`) :**

```css
.app-header {
  background: white;
  border-bottom: 1px solid #e5e7eb;
  padding: 1rem 0;
  box-shadow: 0 1px 3px 0 rgba(0, 0, 0, 0.1);
}

.app-header .container {
  max-width: 1200px;
  margin: 0 auto;
  padding: 0 1.5rem;
}

.header-content {
  display: flex;
  justify-content: space-between;
  align-items: center;
}

.logo a {
  font-size: 1.5rem;
  font-weight: 700;
  color: #10b981;
  text-decoration: none;
}

.user-nav {
  display: flex;
  align-items: center;
  gap: 1rem;
}

.user-email {
  font-size: 0.875rem;
  color: #6b7280;
}

.btn-link,
.btn-logout,
.btn-signup {
  padding: 0.5rem 1rem;
  border-radius: 0.375rem;
  font-weight: 500;
  transition: all 0.2s ease;
}

.btn-link {
  color: #10b981;
}

.btn-link:hover {
  background: #f0fdf4;
}

.btn-signup {
  background: #10b981;
  color: white;
}

.btn-signup:hover {
  background: #059669;
  text-decoration: none;
}

.btn-logout {
  color: #ef4444;
}

.btn-logout:hover {
  background: #fef2f2;
  text-decoration: none;
}
```

## Conditionner l'Affichage du Header

Pour ne pas afficher le header sur les pages d'authentification :

**Dans le layout :**

```erb
<body>
  <%= render 'shared/flash_messages' %>

  <% unless devise_controller? %>
    <%= render 'shared/header' %>
  <% end %>

  <%= yield %>
</body>
```

Ces améliorations sont **optionnelles** mais recommandées pour une meilleure UX.
