# Comment démarrer l'application en production.
#
# Sans ce fichier, Scalingo se rabat sur webrick — un serveur de développement,
# mono-requête, qui n'a rien à faire face à Internet. Puma, lui, est déjà dans le
# Gemfile et lit config/puma.rb : le port fourni par l'hébergeur (ENV["PORT"]) et
# le nombre de threads (RAILS_MAX_THREADS, 3 par défaut).
web: bundle exec puma -C config/puma.rb

# Ce qui tourne après chaque déploiement réussi, avant que la nouvelle version ne
# reçoive du trafic. Scalingo lance pour cela un conteneur à part ; si la
# commande échoue, le déploiement échoue et l'ANCIENNE version continue de
# servir — c'est ce qui rend ce hook sûr : une migration cassée ne met jamais en
# ligne un code qui ne peut pas tourner.
#
# Deux gestes, dans cet ordre obligé :
#
#   - les migrations, sans quoi le nouveau code s'adresserait à des colonnes qui
#     n'existent pas encore ;
#   - la resynchronisation du catalogue d'ingrédients depuis son YAML. Ce n'est
#     pas une seed de démonstration mais une donnée de référence versionnée : le
#     fichier est la source de vérité (rayon, unité, saison, poids d'une pièce,
#     nom de la pièce), et l'upsert est idempotent. Corollaire assumé : une
#     valeur corrigée à la main en production sur un ingrédient du catalogue est
#     écrasée au déploiement suivant — les corrections durables se font dans le
#     YAML. Les ingrédients créés à la volée, absents du fichier, ne sont jamais
#     touchés.
#
# Volontairement pas `db:seed`, qui poserait aussi les tags et les recettes de
# démonstration : ce n'est pas le rôle d'un déploiement.
postdeploy: bundle exec rails db:migrate && bundle exec rails runner 'load Rails.root.join("db/seeds/ingredients.rb").to_s'
