# Page d'Accueil EasyMeal - Documentation

## Vue d'ensemble

La page d'accueil d'EasyMeal a été conçue selon les meilleures pratiques UX/UI modernes avec une approche **mobile-first** entièrement responsive.

## Caractéristiques principales

### ✨ Design moderne et accueillant

- **Hero Section** plein écran avec image de fond de cuisine
- **Overlay gradient** avec les couleurs de la charte graphique EasyMeal
- **Logo EasyMeal** en SVG haute qualité
- **Titre accrocheur** et sous-titre engageant
- **Call-to-Action (CTA)** principal bien visible

### 🎨 Charte graphique appliquée

Utilisation cohérente de la palette « Slate Craft Premium » :

- Anthracite (#1C1917) pour le bouton CTA principal
- Ambre (#FBBF24) réservé aux étoiles et badges "de saison"
- Fond principal (#F8F7F4) — blanc chaud

### 📱 Responsive Design (Mobile-First)

#### Mobile (< 768px)

- Logo : 280px max
- Titre : 2rem
- Bouton pleine largeur (max 320px)
- Optimisé pour écrans tactiles

#### Tablette (768px - 1024px)

- Logo : 350px max
- Titre : 2.8rem
- Mise en page adaptée

#### Desktop (> 1024px)

- Logo : 400px max
- Titre : 3.5rem
- Expérience optimale grand écran

#### Très grands écrans (> 1440px)

- Logo : 500px max
- Titre : 4rem
- Espacements généreux

#### Petits mobiles (< 375px)

- Logo : 240px max
- Titre : 1.75rem
- Interface compacte mais lisible

#### Mode paysage mobile

- Adaptation spécifique pour hauteur réduite
- Réduction des espacements
- Contenu optimisé

### 🎭 Animations et interactions

#### Animations d'entrée

- **fadeIn** : Logo (1.2s)
- **fadeInUp** : Titre (1.4s), Sous-titre (1.6s), Bouton (1.8s)
- Effet de révélation progressive pour guider l'attention

#### Interactions bouton

- **Hover** : Gradient inversé, élévation (+3px), ombre renforcée
- **Active** : Légère compression
- **Transition** fluide (0.3-0.4s)
- Effet de vague au passage de la souris

### 🏗️ Architecture des fichiers

```
app/
├── assets/
│   ├── images/
│   │   ├── backgrounds/
│   │   │   └── kitchen_2.jpg (Image de fond)
│   │   └── logos/
│   │       └── logo_EasyMeal.svg (Logo principal)
│   └── stylesheets/
│       ├── application.css (Manifest)
│       └── home.css (Styles page d'accueil)
└── views/
    └── home/
        └── index.html.haml (Vue HAML)
```

## Composants réutilisables créés

### Classes CSS principales

- `.hero-section` : Conteneur principal
- `.hero-background` : Gestion de l'image + overlay
- `.hero-content` : Contenu centré
- `.hero-logo` : Conteneur du logo
- `.hero-title` : Titre principal
- `.hero-subtitle` : Sous-titre
- `.btn-hero` : Bouton CTA principal

### Styles réutilisables

Le bouton `.btn-hero` peut être réutilisé ailleurs dans l'application avec le même effet visuel premium.

## Points d'attention UX/UI

### ✅ Bonnes pratiques appliquées

1. **Hiérarchie visuelle claire** : Logo → Titre → Sous-titre → CTA
2. **Contraste optimal** : Textes clairs sur fond sombre avec ombres
3. **Zones de clic généreuses** : Bouton CTA adapté au tactile (min 44px)
4. **Performance** : Image optimisée, animations CSS (GPU accelerated)
5. **Accessibilité** : Textes alternatifs sur images, contraste WCAG AA
6. **Progressive Enhancement** : Fonctionne même sans animations

### 🎯 Objectifs UX atteints

- **Engagement immédiat** : Hero plein écran captivant
- **Message clair** : Proposition de valeur en 5 secondes
- **Action évidente** : Un seul CTA principal
- **Esthétique moderne** : Design tendance 2026
- **Confiance** : Qualité visuelle professionnelle

## Prochaines étapes suggérées

1. **Connecter le bouton CTA** à la vraie fonctionnalité de création de menu
2. **Ajouter une section "Fonctionnalités"** en dessous du hero
3. **Intégrer des témoignages** ou chiffres clés
4. **Section "Comment ça marche"** en 3 étapes
5. **Footer informatif** avec liens utiles

## Tests recommandés

- [ ] Tester sur mobile réel (iOS/Android)
- [ ] Vérifier sur Safari, Chrome, Firefox
- [ ] Valider les animations sur connexion lente
- [ ] Tester le mode paysage mobile
- [ ] Vérifier l'accessibilité (lecteurs d'écran)
- [ ] Performance Lighthouse (> 90)

---

**Créé le** : 30 janvier 2026  
**Technologies** : Rails 7, HAML, CSS3, Mobile-First Design  
**Conformité** : Charte graphique EasyMeal, instructions Copilot
