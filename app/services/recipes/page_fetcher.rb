# frozen_string_literal: true

require "net/http"

module Recipes
  # Va chercher le HTML d'une page de recette : validation de l'URL, suivi des
  # redirections, garde-fous de temps, de taille et de type, normalisation de
  # l'encodage.
  #
  # C'est le seul objet de l'import qui parle HTTP à un site tiers ; il ne sait
  # rien du contenu qu'il rapporte. Toute panne — URL douteuse, page
  # inaccessible, fichier déguisé en page, réseau muet — ressort en
  # ExtractionError.
  #
  # @example
  #   html = Recipes::PageFetcher.call("https://exemple.fr/tarte")
  class PageFetcher
    # Redirections suivies avant d'abandonner : au-delà, c'est une boucle.
    MAX_REDIRECTS = 5

    OPEN_TIMEOUT = 10
    READ_TIMEOUT = 30

    # Une page de recette pèse quelques centaines de Ko. Au-delà de 3 Mo, c'est
    # un fichier déguisé ou une page-monstre : inutile de la charger en mémoire.
    MAX_BYTES = 3 * 1024 * 1024

    # Seuls types que Nokogiri a une chance de lire comme une page de recette.
    HTML_CONTENT_TYPES = %w[text/html application/xhtml+xml].freeze

    # Certains sites servent une page vide aux clients qui ne s'annoncent pas.
    USER_AGENT = "Mozilla/5.0 (compatible; EasyMeal/1.0)"

    HTTP_SCHEME = %r{\Ahttps?://}i

    # @param url [String] URL de la page de recette
    # @return [String] corps HTML de la page, en UTF-8 valide
    # @raise [ExtractionError] URL invalide, page inaccessible, trop lourde,
    #   d'un type non HTML, ou réseau en panne
    def self.call(url)
      new(url).call
    end

    def initialize(url)
      @url = url
    end

    # Les pannes sont traduites ici, au bord de l'objet, et non à chaque saut de
    # redirection : une ExtractionError levée en profondeur remonte intacte.
    def call
      fetch(@url, MAX_REDIRECTS)
    rescue URI::Error
      # Toute la famille URI::Error, et pas seulement InvalidURIError : la
      # résolution d'une redirection biscornue peut lever une BadURIError.
      raise ExtractionError, "URL invalide"
    rescue ExtractionError
      raise
    rescue => e
      raise ExtractionError, "Impossible d'accéder à l'URL : #{e.message}"
    end

    private

    # Chaque saut repasse par ici : l'URL de destination d'une redirection est
    # donc validée comme celle saisie par l'utilisatrice.
    def fetch(url, redirects_left)
      raise ExtractionError, "URL invalide (doit commencer par http/https)" unless url.to_s.match?(HTTP_SCHEME)

      uri      = URI.parse(url)
      html     = nil
      redirect = nil

      get(uri) do |response|
        case response
        when Net::HTTPSuccess
          html = read_html(response)
        when Net::HTTPRedirection
          raise ExtractionError, "Trop de redirections" if redirects_left.zero?
          redirect = redirect_target(uri, response)
        else
          raise ExtractionError, "URL inaccessible (code #{response.code})"
        end
      end

      # La redirection n'est suivie qu'ici, hors du bloc : la connexion
      # précédente est refermée avant d'en ouvrir une nouvelle.
      redirect ? fetch(redirect, redirects_left - 1) : html
    end

    # Un Location peut être relatif ("/recettes/tarte.html", très courant) :
    # URI.join le résout contre l'URL courante. Une destination absolue, elle,
    # traverse inchangée — schéma compris, que le prochain tour revalidera.
    def redirect_target(uri, response)
      location = response["location"].to_s
      raise ExtractionError, "Redirection sans destination" if location.blank?

      URI.join(uri, location).to_s
    end

    # Le corps n'est lu qu'après les vérifications d'en-têtes : un PDF ou une
    # page démesurée est refusé sans avoir transité par la mémoire.
    def read_html(response)
      ensure_html!(response)
      ensure_within_limit!(response.content_length)

      # Accumulateur en octets bruts : les morceaux livrés par Net::HTTP sont en
      # ASCII-8BIT, et un accumulateur UTF-8 refuserait de les concaténer.
      body = "".b
      response.read_body do |chunk|
        body << chunk
        # Content-Length est déclaratif, et absent d'un transfert en chunked :
        # le vrai plafond est ici, sur les octets réellement reçus.
        ensure_within_limit!(body.bytesize)
      end

      # On ré-étiquette le tout en UTF-8 et on remplace les octets illégaux, que
      # Nokogiri refuserait.
      body.force_encoding("UTF-8").scrub
    end

    def ensure_html!(response)
      # Net::HTTP normalise déjà le type en minuscules et sans ses paramètres
      # ("text/html; charset=utf-8" → "text/html").
      content_type = response.content_type

      # Un serveur muet sur le type passe : on ne refuse que ce qui s'annonce
      # explicitement autre chose que du HTML.
      return if content_type.blank? || HTML_CONTENT_TYPES.include?(content_type)

      raise ExtractionError,
            "Cette adresse ne pointe pas vers une page de recette — essaie l'adresse de la page, pas du fichier"
    end

    # @param bytes [Integer, nil] taille annoncée ou déjà reçue ; nil = inconnue
    def ensure_within_limit!(bytes)
      return if bytes.nil? || bytes <= MAX_BYTES

      raise ExtractionError, "Cette page est trop volumineuse pour être importée"
    end

    # Le bloc reçoit la réponse en-têtes lus, corps non lu : c'est ce qui permet
    # de la refuser avant de la télécharger.
    def get(uri, &block)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl      = uri.scheme == "https"
      http.open_timeout = OPEN_TIMEOUT
      http.read_timeout = READ_TIMEOUT

      http.request_get(uri.request_uri, { "User-Agent" => USER_AGENT }, &block)
    end
  end
end
