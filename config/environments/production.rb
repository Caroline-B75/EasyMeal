require "active_support/core_ext/integer/time"

Rails.application.configure do
  # Settings specified here will take precedence over those in config/application.rb.

  # Code is not reloaded between requests.
  config.enable_reloading = false

  # Eager load code on boot. This eager loads most of Rails and
  # your application in memory, allowing both threaded web servers
  # and those relying on copy on write to perform better.
  # Rake tasks automatically ignore this option for performance.
  config.eager_load = true

  # Full error reports are disabled and caching is turned on.
  config.consider_all_requests_local = false
  config.action_controller.perform_caching = true

  # Ensures that a master key has been made available in ENV["RAILS_MASTER_KEY"], config/master.key, or an environment
  # key such as config/credentials/production.key. This key is used to decrypt credentials (and other encrypted files).
  # config.require_master_key = true

  # Disable serving static files from `public/`, relying on NGINX/Apache to do so instead.
  # config.public_file_server.enabled = false

  # Compress CSS using a preprocessor.
  # config.assets.css_compressor = :sass

  # Do not fall back to assets pipeline if a precompiled asset is missed.
  config.assets.compile = false

  # Enable serving of images, stylesheets, and JavaScripts from an asset server.
  # config.asset_host = "http://assets.example.com"

  # Configure cloudinary as the Active Storage service for Rails
  config.active_storage.service = :cloudinary

  # Specifies the header that your server uses for sending files.
  # config.action_dispatch.x_sendfile_header = "X-Sendfile" # for Apache
  # config.action_dispatch.x_sendfile_header = "X-Accel-Redirect" # for NGINX

  # Mount Action Cable outside main process or domain.
  # config.action_cable.mount_path = nil
  # config.action_cable.url = "wss://example.com/cable"
  # config.action_cable.allowed_request_origins = [ "http://example.com", /http:\/\/example.*/ ]

  # Nom de domaine public de l'application. Il sert à deux choses qui ne peuvent
  # pas le deviner : les liens contenus dans les emails, et la protection contre
  # les en-têtes Host falsifiés en fin de fichier.
  app_host = ENV.fetch("APP_HOST", "myeasymeal.fr")

  # L'hébergeur termine le HTTPS devant l'application et lui parle en HTTP
  # interne. Sans cette ligne, Rails croit la requête non chiffrée et force_ssl
  # la redirige vers HTTPS — qui repasse par le même proxy, et ainsi de suite :
  # une boucle de redirection infinie.
  config.assume_ssl = true

  # Force all access to the app over SSL, use Strict-Transport-Security, and use secure cookies.
  config.force_ssl = true

  # Le contrôle de santé de l'hébergeur interroge /up en HTTP interne. Il doit
  # recevoir une vraie réponse, pas une redirection, sinon l'application est
  # déclarée morte et redémarrée en boucle.
  config.ssl_options = { redirect: { exclude: ->(request) { request.path == "/up" } } }

  # Log to STDOUT by default
  config.logger = ActiveSupport::Logger.new(STDOUT)
    .tap  { |logger| logger.formatter = ::Logger::Formatter.new }
    .then { |logger| ActiveSupport::TaggedLogging.new(logger) }

  # Prepend all log lines with the following tags.
  config.log_tags = [ :request_id ]

  # "info" includes generic and useful information about system operation, but avoids logging too much
  # information to avoid inadvertent exposure of personally identifiable information (PII). If you
  # want to log everything, set the level to "debug".
  config.log_level = ENV.fetch("RAILS_LOG_LEVEL", "info")

  # Cache en mémoire du process web. Il ne sert qu'à deux choses — la liste des
  # tags du catalogue (Recipes::CatalogQuery) et les cartes de recettes du
  # catalogue —, pour lesquelles un cache local suffit : l'application tourne
  # dans un seul conteneur. Redis coûtait une ligne de facture et une dépendance
  # pour ça.
  #
  # Contreparties assumées : le cache repart à vide à chaque déploiement, et il
  # cesserait d'être partagé si l'application passait un jour à plusieurs
  # conteneurs. C'est le moment de repasser à un cache externe si cela arrive.
  config.cache_store = :memory_store, { size: 32.megabytes, expires_in: 1.hour }

  # Jobs de fond : GoodJob les stocke en PostgreSQL — la base qu'on a déjà — et
  # le mode :async les exécute dans des threads de ce même process web. Donc
  # aucun worker à héberger (pas de conteneur en plus à payer) et aucune
  # dépendance à Redis. En contrepartie, un redémarrage peut interrompre un job
  # en cours : le sien est repris, puisque le RecipeImport garde son état.
  config.active_job.queue_adapter = :good_job
  config.good_job.execution_mode = :async

  # Deux threads suffisent à l'usage réel (import IA réservé aux admins) et
  # laissent la mémoire du conteneur à Puma, qui sert les pages.
  config.good_job.max_threads = 2

  # Disable caching for Action Mailer templates even if Action Controller
  # caching is enabled.
  config.action_mailer.perform_caching = false

  # === Envoi des emails ===
  #
  # Indispensable, et pas seulement souhaitable : User active `:recoverable`,
  # donc le premier « mot de passe oublié » passe par ici. Sans ces réglages,
  # Rails lève « Missing host to link to » en composant le lien de
  # réinitialisation, et la page tombe en erreur 500.
  #
  # Les valeurs par défaut visent l'offre email incluse avec le domaine chez OVH
  # — la zone DNS pointe déjà ses MX sur mx*.mail.ovh.net. Seuls l'identifiant et
  # le mot de passe de la boîte sont à fournir en variables d'environnement :
  # ils ne doivent jamais entrer dans le dépôt.
  config.action_mailer.default_url_options = { host: app_host, protocol: "https" }
  config.action_mailer.delivery_method = :smtp
  config.action_mailer.smtp_settings = {
    address:              ENV.fetch("SMTP_ADDRESS", "ssl0.ovh.net"),
    port:                 ENV.fetch("SMTP_PORT", "465").to_i,
    user_name:            ENV["SMTP_USER_NAME"],
    password:             ENV["SMTP_PASSWORD"],
    domain:               app_host,
    authentication:       :plain,
    # Port 465 = TLS d'emblée (et non STARTTLS négocié après coup) : les deux
    # mécanismes s'excluent, activer le second ferait échouer la connexion.
    ssl:                  true,
    enable_starttls_auto: false,
    open_timeout:         10,
    read_timeout:         10
  }

  # Un envoi qui échoue lève l'erreur au lieu de passer inaperçu. C'est le choix
  # d'un service qu'on vient de mettre en ligne : mieux vaut une erreur visible
  # dans les logs qu'une utilisatrice qui attend en vain un email jamais parti.
  # À repasser à false le jour où un incident SMTP passager ne devra plus
  # renvoyer une erreur 500 sur la page « mot de passe oublié ».
  config.action_mailer.raise_delivery_errors = true

  # Enable locale fallbacks for I18n (makes lookups for any locale fall back to
  # the I18n.default_locale when a translation cannot be found).
  config.i18n.fallbacks = true

  # Don't log any deprecations.
  config.active_support.report_deprecations = false

  # Protection contre les en-têtes Host falsifiés (attaques par DNS rebinding).
  #
  # Volontairement pilotée par l'environnement, et non figée sur myeasymeal.fr :
  # pendant le déploiement à blanc, l'application répond sur l'adresse technique
  # de l'hébergeur, qu'une liste fermée rejetterait par des erreurs 403
  # difficiles à diagnostiquer. On ne restreint donc qu'une fois APP_HOSTS
  # fourni — par exemple « myeasymeal.fr,www.myeasymeal.fr » au moment de la
  # bascule DNS.
  if ENV["APP_HOSTS"].present?
    config.hosts = ENV["APP_HOSTS"].split(",").map(&:strip)

    # Le contrôle de santé de l'hébergeur arrive parfois sans en-tête Host
    # exploitable : il ne doit jamais être bloqué, sinon l'application est
    # déclarée morte.
    config.host_authorization = { exclude: ->(request) { request.path == "/up" } }
  end
end
