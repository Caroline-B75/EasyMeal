# 🚀 Quick Reference : Stimulus dans EasyMeal

## 📚 Controllers Disponibles

### 1. flash_controller.js ✅

**Fonction** : Auto-hide des messages flash après 4 secondes

```haml
.flash-message{ data: { controller: "flash" } }
  = notice
```

**Méthodes** :

- `connect()` : Auto-hide après 4s
- `close()` : Fermeture manuelle

---

### 2. modal_controller.js ✅

**Fonction** : Gestion des modals de confirmation

```haml
.container{ data: { controller: "modal" } }
  = button_to "Supprimer", path,
      form: { data: { action: "submit->modal#open" } }
  = render "shared/delete_confirmation_modal"
```

**Méthodes** :

- `open(event)` : Ouvre la modal
- `close(event)` : Ferme la modal
- `confirm(event)` : Confirme et soumet le formulaire
- `closeOnOverlay(event)` : Ferme si clic sur overlay
- `handleEscape(event)` : Ferme avec touche Escape

**Targets** :

- `overlay` : L'élément modal à afficher/masquer
- `confirmButton` : Le bouton de confirmation

---

### 3. ingredient_form_controller.js ✅

**Fonction** : Auto-fill de base_unit selon unit_group

```haml
= form_with model: @ingredient, data: { controller: "ingredient-form" } do |f|
  = f.select :unit_group, ...,
      data: {
        ingredient_form_target: "unitGroup",
        action: "change->ingredient-form#updateBaseUnit"
      }
  = f.text_field :base_unit,
      data: { ingredient_form_target: "baseUnit" }
```

**Méthodes** :

- `connect()` : Initialise si valeur déjà présente
- `updateBaseUnit()` : Remplit base_unit automatiquement

**Targets** :

- `unitGroup` : Le select du groupe d'unités
- `baseUnit` : L'input de l'unité de base

**Mapping** :

```javascript
{
  'mass': 'g',
  'volume': 'ml',
  'count': 'piece',
  'spoon': 'cac'
}
```

---

## 🎯 Patterns Courants

### Pattern 1 : Action au Clic

```haml
%button{ data: { action: "click->controller#method" } } Click me
```

### Pattern 2 : Action au Changement

```haml
%select{ data: { action: "change->controller#method" } }
```

### Pattern 3 : Action à la Soumission

```haml
= form_with ..., data: { action: "submit->controller#method" }
```

### Pattern 4 : Plusieurs Actions

```haml
%div{ data: { action: "click->modal#open mouseover->tooltip#show" } }
```

### Pattern 5 : Plusieurs Controllers

```haml
%div{ data: { controller: "modal tooltip" } }
```

---

## 🔧 Créer un Nouveau Controller

### 1. Créer le fichier

```bash
# app/javascript/controllers/mon_controller.js
```

```javascript
import { Controller } from "@hotwired/stimulus";

// Gère [description de la fonctionnalité]
// Utilisation: <div data-controller="mon">...</div>
export default class extends Controller {
  static targets = ["element"];
  static values = { id: Number };

  connect() {
    // Appelé quand le controller est connecté au DOM
  }

  disconnect() {
    // Appelé quand le controller est déconnecté du DOM
  }

  maMethode() {
    // Ta logique ici
  }
}
```

### 2. Utiliser dans la vue

```haml
.container{ data: { controller: "mon" } }
  .element{ data: { mon_target: "element" } }
  %button{ data: { action: "click->mon#maMethode" } } Action
```

---

## 📖 Syntaxe Stimulus

### Data Attributes

| Attribut             | Usage                 | Exemple                                 |
| -------------------- | --------------------- | --------------------------------------- |
| `data-controller`    | Déclare un controller | `data: { controller: "modal" }`         |
| `data-action`        | Déclare une action    | `data: { action: "click->modal#open" }` |
| `data-XXX-target`    | Déclare un target     | `data: { modal_target: "overlay" }`     |
| `data-XXX-YYY-value` | Déclare une value     | `data: { modal_id_value: "123" }`       |
| `data-XXX-YYY-param` | Passe un paramètre    | `data: { modal_id_param: "123" }`       |

### Actions

```
[event]->[controller]#[method]
click->modal#open
change->form#validate
submit->form#save
```

**Events courants** :

- `click` : Clic souris
- `change` : Changement de valeur
- `submit` : Soumission de formulaire
- `input` : Saisie texte
- `focus` / `blur` : Focus/perte de focus
- `mouseenter` / `mouseleave` : Survol souris

---

## 🎨 Conventions HAML + Stimulus

### ✅ Bon

```haml
-# Un controller par responsabilité
.form-container{ data: { controller: "form-validation" } }

  -# Actions explicites
  %button{ data: { action: "click->form-validation#submit" } } Submit

  -# Targets clairs
  %input{ data: { form_validation_target: "email" } }
```

### ❌ Mauvais

```haml
-# Pas de onclick
%button{ onclick: "doSomething()" } ❌

-# Pas de script inline
:javascript
  function xxx() {} ❌

-# Pas de sélecteurs manuels dans la vue
%script
  document.getElementById('xxx') ❌
```

---

## 🐛 Debugging Stimulus

### Vérifier les Controllers

```javascript
// Dans la console du navigateur
Stimulus.debug = true;

// Lister les controllers chargés
application.controllers;
```

### Logs

```javascript
export default class extends Controller {
  connect() {
    console.log("Modal controller connected!");
    console.log("Targets:", this.targets);
    console.log("Values:", this.values);
  }

  maMethode() {
    console.log("Méthode appelée avec event:", event);
  }
}
```

---

## 📚 Ressources

- **Documentation Stimulus** : https://stimulus.hotwired.dev/
- **Référence API** : https://stimulus.hotwired.dev/reference/controllers
- **Guide du projet** : [guide-migration-stimulus.md](guide-migration-stimulus.md)

---

**Dernière mise à jour** : 29 janvier 2026
