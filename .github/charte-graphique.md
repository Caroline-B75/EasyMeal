# Charte Graphique EasyMeal

> **Note importante** : Cette charte doit être appliquée à **toutes les vues** de l'application pour maintenir une cohérence visuelle.

---

## � Langue de l'application

**EasyMeal est une application 100% française.**

- Tout le contenu doit être en français (vues, messages, validations, etc.)
- Ne PAS utiliser I18n.t() - écrire directement le texte en français
- Pas de support multilingue prévu
- Locale par défaut : `:fr` (configuré dans `config/application.rb`)

---

## �🎨 Palette de couleurs

### Couleur primaire (rouge/terracotta)

- **Principal** : `#C8444B` ou `#D4484E` - Pour les CTA principaux et éléments importants
- **Hover** : `#A63940` - Version plus foncée pour les états hover

### Couleur secondaire (orange/abricot)

- **Principal** : `#F5A855` ou `#F0A04B` - Pour les étapes, badges, éléments secondaires
- **Hover** : `#E89A3C` - Version plus foncée pour les états hover

### Neutres chauds

- **Fond principal** : `#F8F6F3` ou `#FAF8F5` - Fond très doux
- **Fond secondaire** : `#E8E4DF` - Fond pour cartes
- **Texte principal** : `#4A4A4A` ou `#3D3D3D`
- **Texte secondaire** : `#6B6B6B`
- **Blanc** : `#FFFFFF` - Pour les cartes et overlays

### Accents

- **Bois/naturel** : `#8B7355` ou `#9D8066` - Inspiré du comptoir
- **Vert sauge** : `#5A7B5A` - Pour les légumes/bio
- **Beige rosé** : `#E6D5C3` - Variations douces

---

## 📝 Typographie

### Titres et accents

- **Police script/cursive** : `Pacifico`, `Lobster`, ou `Dancing Script`
- **Alternative moderne** : `Playfair Display` en italic
- Utilisation : Logo, titre "What's for dinner?", accents décoratifs

### Corps de texte

- **Police sans-serif** : `Inter`, `Nunito`, ou `Poppins`
- **Poids** :
  - `400` (regular) - Texte courant
  - `600` (semi-bold) - Titres, labels, boutons

---

## 🎯 Principes d'utilisation

### Fonds

- **Fond général** : Beige très clair (`#F8F6F3`) avec effet de flou optionnel sur images d'ambiance cuisine
- **Cartes** : Blanc (`#FFFFFF`) avec ombres légères

### Ombres

```css
box-shadow: 0 2px 8px rgba(0, 0, 0, 0.08);
/* Pour effet de survol */
box-shadow: 0 4px 12px rgba(0, 0, 0, 0.12);
```

### Coins arrondis

- **Standard** : `border-radius: 12px` - Boutons, inputs
- **Généreux** : `border-radius: 16px` - Cartes, images
- **Pilules** : `border-radius: 24px` - Badges, tags

### Espacements

- Utiliser des espacements aérés et généreux
- Padding minimal pour les cartes : `1.5rem` (24px)
- Gap entre éléments : `1rem` à `2rem` selon le contexte

### Boutons

#### Bouton primaire (CTA principal)

```css
background: #c8444b;
color: white;
padding: 0.75rem 1.5rem;
border-radius: 12px;
font-weight: 600;
transition: all 0.2s;

/* Hover */
background: #a63940;
transform: translateY(-1px);
box-shadow: 0 4px 12px rgba(200, 68, 75, 0.3);
```

#### Bouton secondaire

```css
background: #f5a855;
color: white;
padding: 0.75rem 1.5rem;
border-radius: 12px;
font-weight: 600;
transition: all 0.2s;

/* Hover */
background: #e89a3c;
```

#### Bouton outline

```css
background: transparent;
border: 2px solid #e8e4df;
color: #4a4a4a;
padding: 0.75rem 1.5rem;
border-radius: 12px;
font-weight: 600;

/* Hover */
background: #faf8f5;
border-color: #c8444b;
color: #c8444b;
```

### Cartes

```css
background: white;
padding: 1.5rem;
border-radius: 16px;
box-shadow: 0 2px 8px rgba(0, 0, 0, 0.08);
transition: box-shadow 0.2s;

/* Hover */
box-shadow: 0 4px 12px rgba(0, 0, 0, 0.12);
```

### Badges

```css
background: #f5a855;
color: white;
padding: 0.25rem 0.75rem;
border-radius: 24px;
font-size: 0.875rem;
font-weight: 600;
```

### Inputs et formulaires

```css
border: 2px solid #e8e4df;
border-radius: 12px;
padding: 0.75rem 1rem;
background: white;
color: #3d3d3d;
font-size: 1rem;

/* Focus */
border-color: #c8444b;
box-shadow: 0 0 0 3px rgba(200, 68, 75, 0.1);
outline: none;
```

---

## 🎨 Ambiance générale

L'application doit dégager une atmosphère :

- **Chaleureuse** : Tons chauds, terracotta, abricot
- **Gourmande** : Visuels appétissants, coins arrondis généreux
- **Accueillante** : Espacements aérés, typographie douce
- **Moderne mais humaine** : Design épuré mais chaleureux

---

## ✅ Checklist d'application

Lors de la création d'une nouvelle vue :

- [ ] Fond général en `#F8F6F3`
- [ ] Cartes blanches avec `box-shadow: 0 2px 8px rgba(0,0,0,0.08)`
- [ ] Boutons principaux en `#C8444B`
- [ ] Boutons secondaires en `#F5A855`
- [ ] `border-radius` entre 12px et 16px
- [ ] Typographie : Inter, Nunito ou Poppins
- [ ] Espacements généreux (min 1.5rem pour padding de cartes)
- [ ] Texte principal en `#4A4A4A`, secondaire en `#6B6B6B`
- [ ] Transitions douces sur les interactions (`transition: all 0.2s`)

---

**Dernière mise à jour** : 28 janvier 2026
