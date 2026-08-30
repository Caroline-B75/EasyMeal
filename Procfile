# Comment démarrer l'application en production.
#
# Sans ce fichier, Scalingo se rabat sur webrick — un serveur de développement,
# mono-requête, qui n'a rien à faire face à Internet. Puma, lui, est déjà dans le
# Gemfile et lit config/puma.rb : le port fourni par l'hébergeur (ENV["PORT"]) et
# le nombre de threads (RAILS_MAX_THREADS, 3 par défaut).
web: bundle exec puma -C config/puma.rb

# Ce qui tourne après chaque déploiement réussi, avant que la nouvelle version ne
# reçoive du trafic. Scalingo lance pour cela un conteneur à part ; si la commande
# échoue, le déploiement échoue et l'ANCIENNE version continue de servir — c'est
# ce qui rend ce hook sûr : une migration cassée ne met jamais en ligne un code
# qui ne peut pas tourner.
#
# Rien d'autre que les migrations ici, et c'est délibéré : ce hook est sur le
# chemin critique de chaque déploiement. La seed du catalogue d'ingrédients y a
# tenu le temps d'un essai (30/08/2026) et l'a fait échouer — un enregistrement
# refusé par une validation suffit à bloquer une mise en ligne qui n'avait rien à
# voir. Resynchroniser le catalogue est un geste ponctuel, à lancer à la main :
#
#   rails runner 'load Rails.root.join("db/seeds/ingredients.rb").to_s'
postdeploy: bundle exec rails db:migrate
