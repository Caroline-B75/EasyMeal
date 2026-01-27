source "https://rubygems.org"

ruby "3.2.3"

# Core Rails
gem "rails", "~> 7.2.3"
gem "pg", "~> 1.6.3"
gem "puma", "~> 7.2.0"
gem "sprockets-rails", "~> 3.5.2"
gem "importmap-rails", "~> 2.2.3"
gem "turbo-rails", "~> 2.0.21"
gem "jbuilder", "~> 2.14.1"

# UI / Forms / Icons
gem "simple_form", "~> 5.4.1"
gem "font-awesome-sass", "~> 6.7.2"

# Templates Haml
gem "haml-rails", "~> 3.0.0"

# Stimulus
gem "stimulus-rails", "~> 1.3.4"

# Auth & Policy
gem "devise", "~> 4.9.4"
gem "pundit", "~> 2.5.2"

# Cache / Sessions
gem "redis", "~> 4.8.1"

# Recherche & pagination
gem "ransack", "~> 4.4.1"
gem "pagy", "~> 9.3"  # ⚠️ Downgrade recommandé de 43.2.7 → 9.3

# Uploads / images
gem "image_processing", "~> 1.14.0"
gem "cloudinary", "~> 2.4.3"
gem "activestorage-cloudinary-service", "~> 0.2.3"

# Config
gem "dotenv-rails", "~> 3.2.0"

# Dev qualité
gem "bootsnap", "~> 1.21.1", require: false
gem "annotate", "~> 3.2.0", group: [:development]
gem "bundler-audit", "~> 0.9.3", require: false, group: [:development, :test]

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
  gem "awesome_print", "~> 1.9.2"
  gem "table_print", "~> 1.5.7"
end

group :development do
  gem "web-console", "~> 4.2.1"
end

gem "tzinfo-data", platforms: %i[windows jruby]