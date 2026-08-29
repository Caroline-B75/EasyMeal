# Guide de Migration JavaScript → Stimulus

## 🎯 Quick Start : Comment Refactorer du JavaScript vers Stimulus

Ce guide montre les patterns de conversion du JavaScript inline/global vers Stimulus.

---

## Pattern 1️⃣ : Fonctions Globales → Controller Stimulus

### ❌ AVANT (Mauvais)

```html
<script>
  function openModal() {
    document.getElementById("modal").style.display = "flex";
  }

  function closeModal() {
    document.getElementById("modal").style.display = "none";
  }
</script>

<button onclick="openModal()">Ouvrir</button>
<div id="modal">
  <button onclick="closeModal()">Fermer</button>
</div>
```

### ✅ APRÈS (Bon)

```javascript
// app/javascript/controllers/modal_controller.js
import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["overlay"];

  open() {
    this.overlayTarget.style.display = "flex";
  }

  close() {
    this.overlayTarget.style.display = "none";
  }
}
```

```haml
-# app/views/example.html.haml
.container{ data: { controller: "modal" } }
  %button{ data: { action: "click->modal#open" } } Ouvrir

  .modal{ data: { modal_target: "overlay" } }
    %button{ data: { action: "click->modal#close" } } Fermer
```

---

## Pattern 2️⃣ : Event Listeners → Stimulus Actions

### ❌ AVANT (Mauvais)

```html
<select id="country-select">
  <option>France</option>
  <option>USA</option>
</select>

<script>
  document.addEventListener("DOMContentLoaded", function () {
    const select = document.getElementById("country-select");
    select.addEventListener("change", function () {
      console.log(this.value);
    });
  });
</script>
```

### ✅ APRÈS (Bon)

```javascript
// app/javascript/controllers/country_controller.js
import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["select"];

  change() {
    console.log(this.selectTarget.value);
  }
}
```

```haml
.form{ data: { controller: "country" } }
  %select{ data: { country_target: "select", action: "change->country#change" } }
    %option France
    %option USA
```

---

## Pattern 3️⃣ : Variables Globales → Controller State

### ❌ AVANT (Mauvais)

```html
<script>
  let selectedItem = null;

  function selectItem(id) {
    selectedItem = id;
  }

  function confirmSelection() {
    alert("Selected: " + selectedItem);
  }
</script>

<button onclick="selectItem(1)">Item 1</button>
<button onclick="confirmSelection()">Confirmer</button>
```

### ✅ APRÈS (Bon)

```javascript
// app/javascript/controllers/selector_controller.js
import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static values = { selected: Number };

  select(event) {
    this.selectedValue = event.params.id;
  }

  confirm() {
    alert("Selected: " + this.selectedValue);
  }
}
```

```haml
.container{ data: { controller: "selector" } }
  %button{ data: { action: "click->selector#select", selector_id_param: "1" } } Item 1
  %button{ data: { action: "click->selector#confirm" } } Confirmer
```

---

## Pattern 4️⃣ : Auto-fill Formulaire

### ❌ AVANT (Mauvais)

```html
<select id="category">
  <option value="mass">Masse</option>
  <option value="volume">Volume</option>
</select>
<input id="unit" readonly />

<script>
  document.getElementById("category").addEventListener("change", function () {
    const mapping = { mass: "g", volume: "ml" };
    document.getElementById("unit").value = mapping[this.value];
  });
</script>
```

### ✅ APRÈS (Bon)

```javascript
// app/javascript/controllers/unit_form_controller.js
import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["category", "unit"];
  static mapping = { mass: "g", volume: "ml" };

  updateUnit() {
    const category = this.categoryTarget.value;
    this.unitTarget.value = this.constructor.mapping[category] || "";
  }
}
```

```haml
= form_with model: @item, data: { controller: "unit-form" } do |f|
  = f.select :category, ...,
      data: { unit_form_target: "category", action: "change->unit-form#updateUnit" }
  = f.text_field :unit, readonly: true, data: { unit_form_target: "unit" }
```

---

## Pattern 5️⃣ : Manipulation DOM → Targets

### ❌ AVANT (Mauvais)

```html
<div id="content"></div>
<button onclick="loadContent()">Charger</button>

<script>
  function loadContent() {
    document.getElementById("content").innerHTML = "<p>Contenu chargé</p>";
  }
</script>
```

### ✅ APRÈS (Bon)

```javascript
// app/javascript/controllers/loader_controller.js
import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["content"];

  load() {
    this.contentTarget.innerHTML = "<p>Contenu chargé</p>";
  }
}
```

```haml
.container{ data: { controller: "loader" } }
  .content{ data: { loader_target: "content" } }
  %button{ data: { action: "click->loader#load" } } Charger
```

---

## 🔧 Checklist de Migration

Avant de commencer, vérifier :

- [ ] Le JavaScript est dans un `<script>` inline dans une vue
- [ ] Il y a des fonctions globales (`function xxx()`)
- [ ] Il y a des `onclick`, `onchange`, etc.
- [ ] Il y a des `getElementById`, `querySelector`
- [ ] Il y a des variables globales

Si **OUI** à l'un de ces points → **Refactorer avec Stimulus !**

---

## 📝 Convention de Nommage

| Élément        | Convention                 | Exemple                           |
| -------------- | -------------------------- | --------------------------------- |
| **Controller** | `snake_case_controller.js` | `modal_controller.js`             |
| **Classe**     | `CapitalizedController`    | `ModalController`                 |
| **Target**     | `camelCase`                | `overlayTarget`                   |
| **Action**     | `kebab-case`               | `data-action="click->modal#open"` |
| **Value**      | `camelCase`                | `selectedValue`                   |

---

## 🎨 Data Attributes Stimulus

```haml
-# Controller
data: { controller: "nom" }

-# Action
data: { action: "event->controller#method" }

-# Target
data: { controller_target: "nom" }

-# Value
data: { controller_nom_value: "valeur" }

-# Params
data: { controller_param_param: "valeur" }

-# Plusieurs controllers
data: { controller: "modal form-validation" }

-# Plusieurs actions
data: { action: "click->modal#open mouseover->tooltip#show" }
```

---

## 🚀 Commandes Utiles

```bash
# Générer un nouveau controller Stimulus
rails generate stimulus nom_controller

# Lister les controllers Stimulus
ls app/javascript/controllers/

# Vérifier la syntaxe JavaScript
npx eslint app/javascript/
```

---

## 💡 Bonnes Pratiques

### ✅ À FAIRE

1. **Un controller = une responsabilité**
   - `modal_controller.js` → Gère les modals
   - `form_controller.js` → Gère les formulaires

2. **Nommer explicitement les méthodes**
   - `open()`, `close()`, `submit()`, `validate()`

3. **Utiliser des targets pour les éléments DOM**
   - Pas de `getElementById` ou `querySelector`

4. **Documenter les controllers**
   ```javascript
   // Gère l'ouverture/fermeture des modals
   // Utilisation: <div data-controller="modal">...</div>
   export default class extends Controller {
     // ...
   }
   ```

### ❌ À ÉVITER

1. Fonctions globales dans `<script>`
2. Variables globales
3. `onclick`, `onchange`, etc.
4. jQuery (sauf absolument nécessaire)
5. Logique métier complexe dans les controllers (→ déplacer dans les models)

---

## 📚 Ressources

- **Documentation Stimulus** : https://stimulus.hotwired.dev/
- **Handbook Stimulus** : https://stimulus.hotwired.dev/handbook/introduction
- **Exemples Stimulus** : https://github.com/hotwired/stimulus/tree/main/examples

---

**Dernière mise à jour** : 29 janvier 2026
