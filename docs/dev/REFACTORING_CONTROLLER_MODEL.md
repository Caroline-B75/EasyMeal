# Documentation du Refactoring Controller/Model

# Date: 30 janvier 2026

## Objectifs atteints ✅

### 1. Extraction de la logique de nettoyage vers un concern

**Avant** : La logique de nettoyage était dispersée dans `ingredient_params` du controller

```ruby
# Dans IngredientsController
def ingredient_params
  permitted = params.require(:ingredient).permit(...)

  # Logique métier dans le controller ❌
  if permitted[:aliases].is_a?(String)
    permitted[:aliases] = permitted[:aliases].split(',').map(&:strip).reject(&:blank?)
  end

  if permitted[:season_months].present?
    permitted[:season_months] = permitted[:season_months].reject(&:blank?).map(&:to_i)
  end

  permitted
end
```

**Après** : Logique déplacée dans un concern réutilisable

- ✅ Concern `AttributeCleaner` créé dans `app/models/concerns/attribute_cleaner.rb`
- ✅ Utilise un callback `before_validation` pour nettoyer automatiquement
- ✅ Logique centralisée et testable
- ✅ Réutilisable pour d'autres models si nécessaire

### 2. Simplification de `ingredient_params`

**Avant** : 20 lignes avec logique métier
**Après** : 11 lignes, uniquement la déclaration des paramètres autorisés

```ruby
# Paramètres autorisés pour Ingredient
# Le nettoyage des données (aliases, season_months) est géré automatiquement
# par le concern AttributeCleaner dans le model
def ingredient_params
  params.require(:ingredient).permit(
    :name,
    :category,
    :unit_group,
    :base_unit,
    season_months: [],
    aliases: []
  )
end
```

## Avantages du refactoring

### Séparation des responsabilités (SRP)

- **Controller** : Gestion des requêtes HTTP et autorisations uniquement
- **Model** : Validation et nettoyage des données métier
- **Concern** : Logique réutilisable de nettoyage

### Principe DRY (Don't Repeat Yourself)

- Le concern peut être réutilisé dans d'autres models
- Pas de duplication de logique

### Testabilité améliorée

- La logique de nettoyage peut être testée indépendamment
- Callbacks exécutés automatiquement avant validation

### Maintenabilité

- Code plus lisible et mieux organisé
- Modifications futures centralisées dans le concern
- Documentation claire avec commentaires

## Fichiers modifiés

1. **app/models/concerns/attribute_cleaner.rb** (nouveau)
   - Concern réutilisable pour nettoyer les attributs
   - Gère `aliases` (String → Array)
   - Gère `season_months` (nettoyage et validation)

2. **app/models/ingredient.rb**
   - Ajout de `include AttributeCleaner`
   - Suppression de la logique dupliquée

3. **app/controllers/ingredients_controller.rb**
   - Simplification de `ingredient_params`
   - Suppression de 10 lignes de code métier

## Tests de validation

### Test manuel recommandé :

```ruby
# Console Rails
ing = Ingredient.new(
  name: 'Tomate',
  category: :fruits_legumes,
  unit_group: :mass,
  base_unit: 'g'
)

# Test aliases depuis String
ing.aliases = 'tomate, tomates, tomato'
ing.valid?
ing.aliases # => ["tomate", "tomates", "tomato"]

# Test season_months avec valeurs vides
ing.season_months = ['', '6', '7', '8', '']
ing.valid?
ing.season_months # => [6, 7, 8]
```

## Conformité aux principes du projet

✅ **Simplicité et clarté** : Code plus lisible et organisé
✅ **DRY** : Pas de duplication de logique
✅ **Conventions Rails** : Utilisation de concerns et callbacks
✅ **Commentaires utiles** : Documentation du "pourquoi"
✅ **Refactorisation continue** : Amélioration de l'existant

---

**Note** : Le refactoring est compatible avec le code existant et n'introduit aucun breaking change.
