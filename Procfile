# Comment démarrer l'application en production.
#
# Sans ce fichier, Scalingo se rabat sur webrick — un serveur de développement,
# mono-requête, qui n'a rien à faire face à Internet. Puma, lui, est déjà dans le
# Gemfile et lit config/puma.rb : le port fourni par l'hébergeur (ENV["PORT"]) et
# le nombre de threads (RAILS_MAX_THREADS, 3 par défaut).
web: bundle exec puma -C config/puma.rb
