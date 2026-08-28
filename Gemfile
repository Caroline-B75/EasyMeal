source "https://rubygems.org"

ruby "3.3.7"

# Core Rails
gem "rails", "~> 7.2.3"
gem "pg", "~> 1.6.3"
gem "puma", "~> 7.2.0"
gem "sprockets-rails", "~> 3.5.2"
gem "importmap-rails", "~> 2.2.3"
gem "turbo-rails", "~> 2.0.21"
gem "jbuilder", "~> 2.14.1"

# UI / Forms
gem "simple_form", "~> 5.4.1"

# Templates Haml
gem "haml-rails", "~> 3.0.0"

# Stimulus
gem "stimulus-rails", "~> 1.3.4"

# Auth & Policy
gem "devise", "~> 4.9.4"
gem "pundit", "~> 2.5.2"

# Cache / Sessions
gem "redis", "~> 4.8.1"
# Épinglé en 2.x : connection_pool 3.0 est passé aux arguments nommés, alors que
# ActiveSupport 7.2.3 appelle encore ConnectionPool.new(hash_positionnel) dans
# redis_cache_store.rb:153. ActiveSupport ne déclarant que « >= 2.2.5 », Bundler
# résolvait un majeur incompatible et TOUT boot en RAILS_ENV=production échouait
# sur « wrong number of arguments (given 1, expected 0) » — assets:precompile et
# déploiement compris. À délier quand on passera à une version de Rails dont le
# RedisCacheStore appelle connection_pool en arguments nommés.
gem "connection_pool", "~> 2.5"

# Recherche & pagination
gem "ransack", "~> 4.4.1"
gem "pagy", "~> 9.3"  # ⚠️ Downgrade recommandé de 43.2.7 → 9.3

# Uploads / images
gem "image_processing", "~> 1.14.0"
gem "cloudinary", "~> 2.4.3"
gem "activestorage-cloudinary-service", "~> 0.2.3"

# Jobs de fond, stockés en PostgreSQL. En mode :async, ils s'exécutent dans des
# threads du process web : aucun worker à héberger, donc aucun coût en plus, et
# aucune dépendance à Redis. C'est ce qui sort l'extraction IA du cycle de la
# requête HTTP, dont les routeurs d'hébergeurs coupent le fil vers 30 s.
gem "good_job", "~> 4.9"

# Extraction IA des recettes (import par lien ou par photo)
gem "anthropic", "~> 1.61.0"

# Config
gem "dotenv-rails", "~> 3.2.0"

# Dev qualité
gem "bootsnap", "~> 1.21.1", require: false
gem "annotate", "~> 3.2.0", group: [ :development ]
gem "bundler-audit", "~> 0.9.3", require: false, group: [ :development, :test ]

group :development, :test do
  gem "debug", "~> 1.11.1", platforms: %i[mri windows], require: "debug/prelude"
  gem "brakeman", "~> 7.1.2", require: false
  gem "rubocop-rails-omakase", "~> 1.1.0", require: false
  gem "rspec-rails", "~> 8.0.2"
  gem "factory_bot_rails", "~> 6.5.1"
  gem "shoulda-matchers", "~> 5.3.0"
  gem "faker", "~> 3.6.0"
  gem "capybara", "~> 3.40.0"
  gem "selenium-webdriver", "~> 4.40.0"
  # Simule l'API Claude au niveau HTTP : le SDK officiel est ainsi exercé pour
  # de vrai (corps de requête envoyé, erreurs typées levées depuis les codes HTTP)
  gem "webmock", "~> 3.26.2"
  gem "awesome_print", "~> 1.9.2"
  gem "table_print", "~> 1.5.7"
  gem "simplecov", require: false
end

group :development do
  gem "web-console", "~> 4.2.1"
  # Qualité de code : score, smells, complexité, duplication
  gem "rubycritic", "~> 4.9", require: false
  # Bonnes pratiques spécifiques Rails
  gem "rails_best_practices", "~> 1.23", require: false
  # Détection N+1 et requêtes manquantes en développement
  gem "bullet", "~> 8.0"
end

gem "tzinfo-data", platforms: %i[windows jruby]
