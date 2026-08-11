# frozen_string_literal: true

require "net/http"

module Recipes
  # Va chercher le HTML d'une page de recette : validation de l'URL, suivi des
  # redirections, garde-fous de temps, normalisation de l'encodage.
  #
  # C'est le seul objet de l'import qui parle HTTP à un site tiers ; il ne sait
  # rien du contenu qu'il rapporte. Toute panne — URL douteuse, page
  # inaccessible, réseau muet — ressort en ExtractionError.
  #
  # @example
  #   html = Recipes::PageFetcher.call("https://exemple.fr/tarte")
  class PageFetcher
    # Redirections suivies avant d'abandonner : au-delà, c'est une boucle.
    MAX_REDIRECTS = 5

    OPEN_TIMEOUT = 10
    READ_TIMEOUT = 30

    # Certains sites servent une page vide aux clients qui ne s'annoncent pas.
    USER_AGENT = "Mozilla/5.0 (compatible; EasyMeal/1.0)"

    HTTP_SCHEME = %r{\Ahttps?://}i

    # @param url [String] URL de la page de recette
    # @return [String] corps HTML de la page, en UTF-8 valide
    # @raise [ExtractionError] URL invalide, page inaccessible ou réseau en panne
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
    rescue URI::InvalidURIError
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

      response = get(URI.parse(url))

      case response
      when Net::HTTPSuccess
        # Net::HTTP rend un corps étiqueté ASCII-8BIT : on le ré-étiquette en
        # UTF-8 et on remplace les octets illégaux, que Nokogiri refuserait.
        response.body.force_encoding("UTF-8").scrub
      when Net::HTTPRedirection
        raise ExtractionError, "Trop de redirections" if redirects_left.zero?
        fetch(response["location"], redirects_left - 1)
      else
        raise ExtractionError, "URL inaccessible (code #{response.code})"
      end
    end

    def get(uri)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl      = uri.scheme == "https"
      http.open_timeout = OPEN_TIMEOUT
      http.read_timeout = READ_TIMEOUT

      http.get(uri.request_uri, "User-Agent" => USER_AGENT)
    end
  end
end
