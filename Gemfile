source "https://rubygems.org"

ruby "3.2.3"

gem "rails", "~> 7.2.3"
gem "pg"                            # PostgreSQL
gem "puma", ">= 5.0"
gem "sprockets-rails"               # asset pipeline (CSS/images)
gem "importmap-rails"               # JS sans Node
gem "turbo-rails"                   # navigation rapide
gem "jbuilder"

# UI / Forms / Icons
gem "simple_form"
gem "font-awesome-sass", "~> 6.1"

# Templates Haml
gem "haml-rails"

# Stimulus (contrôles -/+ pers, petits comportements UI)
gem "stimulus-rails"

# Auth & Policy
gem "devise"
gem "pundit"

# Recherche & pagination
gem "ransack"
gem "pagy"

# Uploads / images
gem "image_processing"              # variants ActiveStorage
gem "cloudinary"                    # client cloudinary
gem "activestorage-cloudinary-service" # service ActiveStorage officiel

# Config
gem "dotenv-rails"                  # variables d'env (non prod)

# Dev qualité
gem "bootsnap", require: false
gem "annotate", group: [:development]
gem "bundler-audit", require: false, group: [:development, :test]

group :development, :test do
  gem "debug", platforms: %i[mri windows], require: "debug/prelude"
  gem "brakeman", require: false
  gem "rubocop-rails-omakase", require: false
  gem "rspec-rails"
  gem "factory_bot_rails"
  gem "shoulda-matchers", "~> 5.0"
  gem "faker"
  gem "capybara"
  gem "selenium-webdriver"
end

group :development do
  gem "web-console"
end

# Windows only (tu es sous WSL/Ubuntu -> pas nécessaire)
gem "tzinfo-data", platforms: %i[windows jruby]
