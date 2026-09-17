# UC8 — Le foyer : menus et liste de courses partagés 🏠

> Livré le 16/09/2026. Récapitulatif de la fonctionnalité et de tout ce qu'elle
> change, tel que présenté à l'utilisatrice.
>
> Point de départ : « Je crée un menu pour ma famille et j'obtiens ma liste de
> courses. Sauf que c'est mon mari qui fait les courses, et il pourrait faire
> quelques-unes des recettes. Il s'est créé un compte lui aussi. »

---

## Le principe

- Un **foyer** regroupe plusieurs comptes qui partagent **les mêmes menus et la même liste de courses**.
- Chaque compte a toujours un foyer, souvent d'une seule personne : seul, l'application se comporte exactement comme avant.
- Tous les membres sont égaux : chacun peut composer, valider, modifier, cocher, inviter et retirer. Pas de rôles, pas de propriétaire.

## Ce qui est partagé, ce qui reste personnel

- **Partagé** : les menus (brouillon, actif, historique) et la liste de courses.
- **Personnel** : les favoris, les avis, les imports de recettes, et les préférences de génération (personnes, régime, semaine type).
- **Conséquence importante** : les règles « un seul menu actif » et « un seul brouillon » valent maintenant **par foyer** et non par personne. Si un membre génère un menu, il remplace le brouillon du foyer.

## Entrer et sortir d'un foyer

- **Inviter** : depuis « Mon foyer », un bouton envoie un lien par SMS ou messagerie (copie du lien sur ordinateur). Aucun email n'est nécessaire.
- **Rejoindre** : la personne ouvre le lien, se connecte ou crée son compte — elle revient alors automatiquement sur l'invitation —, puis confirme sur un écran qui annonce ce qui va changer.
- **Ses anciens menus** rejoignent l'historique du foyer, en archivés.
- **Renouveler le lien** : l'ancien cesse aussitôt de fonctionner, si jamais il a trop circulé.
- **Quitter ou retirer quelqu'un** : la personne repart avec un foyer vide ; les menus restent au foyer et les articles qu'elle avait pris redeviennent libres.
- **Supprimer un compte** : s'il était le dernier membre, le foyer et ses menus disparaissent avec lui ; sinon tout reste aux autres.

## La liste de courses à plusieurs

- **Mise à jour en direct** : quand un membre coche, ajoute, supprime ou prend un article, la page des autres se met à jour d'elle-même, sans saut ni retour en haut.
- **Ce qui n'est jamais écrasé** : les rayons repliés, le mode et le filtre choisis, une quantité ou un article en cours de saisie, une confirmation ouverte.
- **Après une coupure** (réseau perdu, téléphone en veille), la liste se remet à jour dès le retour de la connexion.
- **Cocher un article te l'attribue** : les autres voient qui l'a acheté.
- **Mode Courses** : on coche, comme avant. Le pseudo de la personne qui s'occupe d'un article s'affiche sous son nom, ou une seule fois sur l'en-tête si elle a pris tout le rayon. Le sien est en foncé.
- **Filtre « Ma part »** : masque ce que les autres ont pris ; garde ses articles et ceux que personne n'a pris.
- **Mode Répartir** : plus de case à cocher ni de suppression. Un bouton par ligne — « Je prends », « ✓ @moi » pour laisser, « @pseudo » pour reprendre — et « Tout prendre » / « Tout laisser » sur chaque rayon.
- **Hors ligne** : les coches en attente fonctionnent comme avant, et le mode comme le filtre restent utilisables sans réseau.
- **Foyer d'une seule personne** : aucun de ces éléments n'apparaît.

## Ce que ça change dans le code

- **Deux migrations** : création des foyers (avec un foyer par compte existant et ses menus rattachés), puis la colonne qui dit qui s'occupe d'un article.
- **Les menus appartiennent au foyer** : la colonne `user_id` de `menus` est remplacée par `household_id`, et un compte lit les menus de son foyer.
- **Droits d'accès** : les trois policies (menu, repas, article de courses) reposent sur une règle unique — être membre du foyer du menu.
- **Nouveaux écrans et routes** : `/foyer`, retrait d'un membre, `/foyer/rejoindre/:token`, et les actions de répartition d'un article ou d'un rayon.
- **Nouveaux fichiers** : le modèle Foyer, quatre contrôleurs, deux helpers, les vues « Mon foyer » et « Rejoindre un foyer », une feuille de style, trois modules JavaScript.
- **Temps réel** : la page s'abonne au flux de sa liste ; chaque ligne modifiée y publie une demande de rafraîchissement. En production, tout passe par PostgreSQL — rien à installer ni à payer en plus.
- **Bilan** : 45 fichiers modifiés, une vingtaine créés.

## Changements en dehors du foyer

- **Sécurité** : la fenêtre de confirmation affichait son message comme du HTML. Avec le partage, le nom d'un article saisi par un autre membre pouvait exécuter du code chez un autre membre. C'est corrigé.
- **Discrétion des liens d'invitation** : ils n'apparaissent ni dans les journaux de déploiement, ni dans ceux du serveur.
- **Écran d'administration** : la colonne « Menus créés » devient « Menus du foyer ».
- **Textes** : la page Préférences s'appelle « Mes préférences de menus » ; le badge de la liste dit « avant **la** modification du menu » et non « **ta** ».

## Vérifications

- **835 exemples, 0 échec** (778 avant le chantier), et aucune remarque de RuboCop sur 225 fichiers.
- **Essai réel sur le serveur de développement** avec deux comptes jetables : l'un gardait la liste ouverte pendant que l'autre cochait et prenait des articles, sans rien perdre de ses réglages d'écran.
- **Captures** des deux modes et du filtre, sur mobile et sur ordinateur.

## Ce qui reste à décider

- **Commit** : tout est dans la copie de travail, les deux étapes mélangées.
- **Menu repassé en brouillon** : un membre en train de faire les courses est renvoyé hors de la liste. Faut-il la laisser consultable pendant la modification ?
- **Vieux navigateurs** : sur un iPhone antérieur à iOS 15.4 ou un Firefox antérieur à la version 121, le filtre ne masquerait rien. Quelques lignes de CSS à séparer.
- **« Configure ton foyer »** : ce titre du premier menu parle encore de foyer alors qu'il s'agit des préférences.
- **Mise en production** : les migrations se jouent toutes seules au déploiement, et l'hébergeur gère déjà le temps réel.

---

## Suite prévue

**Étape 3 — les courses habituelles** : une liste d'articles récurrents propre au
foyer, ajoutée à la liste de courses d'un seul bouton, plutôt que ressaisie
chaque semaine article par article.
