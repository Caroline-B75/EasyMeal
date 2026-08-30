require_relative "boot"

require "rails"
# Pick the frameworks you want:
require "active_model/railtie"
require "active_job/railtie"
require "active_record/railtie"
require "active_storage/engine"
require "action_controller/railtie"
require "action_mailer/railtie"
# require "action_mailbox/engine"
# require "action_text/engine"
require "action_view/railtie"
require "action_cable/engine"
require "rails/test_unit/railtie"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module Easymeal
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 7.2

    # Please, add to the `ignore` list any other `lib` subdirectories that do
    # not contain `.rb` files, or that should not be reloaded or eager loaded.
    # Common ones are `templates`, `generators`, or `middleware`, for example.
    config.autoload_lib(ignore: %w[assets tasks])

    # Configuration for the application, engines, and railties goes here.
    #
    # These settings can be overridden in specific environments using the files
    # in config/environments, which are processed later.
    #
    # config.time_zone = "Central Time (US & Canada)"
    # config.eager_load_paths << Rails.root.join("extras")

    # Autoload du dossier services
    config.autoload_paths += %W[#{config.root}/app/services]

    # Application uniquement en français
    config.i18n.default_locale = :fr
    config.i18n.available_locales = [ :fr ]

    # Aucune analyse des pièces jointes. Par défaut, ActiveStorage enfile un job
    # qui RETÉLÉCHARGE chaque photo depuis Cloudinary pour en extraire largeur et
    # hauteur : de la bande passante facturée à chaque envoi, pour une métadonnée
    # que le projet ne lit jamais (les vignettes passent par les URL de
    # transformation Cloudinary, cf. RecipesHelper, et non par .variant()).
    #
    # Sans analyseur enregistré, ActiveStorage retombe sur son NullAnalyzer, dont
    # analyze_later? vaut false : l'analyse devient un simple UPDATE en ligne, sans
    # job ni téléchargement. C'est aussi ce qui dispense le serveur d'ImageMagick
    # et de libvips — les plafonds de photo se contrôlent sans eux (cf. PhotoLimits).
    config.active_storage.analyzers = []

    # Aucune génération de variantes non plus, pour la même raison : les
    # vignettes viennent des URL de transformation Cloudinary. Sans ce réglage,
    # ActiveStorage suppose vouloir redimensionner un jour et avertit à chaque
    # démarrage que la gem image_processing lui manque — un bruit constant dans
    # les logs de déploiement, pour une fonction que le projet n'appelle jamais.
    #
    # Le jour où une variante serait demandée, l'erreur sera nette plutôt que
    # silencieuse : c'est ce que `:disabled` garantit.
    config.active_storage.variant_processor = :disabled
  end
end
