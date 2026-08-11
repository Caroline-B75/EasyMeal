# frozen_string_literal: true

require "net/http"
require "json"

module Recipes
  # Poste des messages à l'API Claude et rend le JSON de sa réponse, déjà analysé.
  #
  # C'est le seul objet de l'import qui parle à api.anthropic.com, et il ne sait
  # rien des recettes : ce qu'on demande à l'IA est écrit par ClaudePrompts.
  # Toute panne — clé absente, erreur d'API, réseau muet, réponse illisible —
  # ressort en ExtractionError, déjà rédigée en français pour l'utilisatrice.
  #
  # @example
  #   Recipes::ClaudeClient.call(Recipes::ClaudePrompts.text_messages(text))
  class ClaudeClient
    MODEL       = "claude-sonnet-4-6"
    API_URL     = "https://api.anthropic.com/v1/messages"
    API_VERSION = "2023-06-01"
    MAX_TOKENS  = 2048

    OPEN_TIMEOUT = 10
    READ_TIMEOUT = 60

    # Malgré la consigne système, Claude encadre parfois son JSON de balises
    # markdown : on les retire avant de l'analyser.
    MARKDOWN_FENCE_OPEN  = /\A```(?:json)?\s*/m
    MARKDOWN_FENCE_CLOSE = /\s*```\z/m

    # @param messages [Array<Hash>] messages construits par ClaudePrompts
    # @return [Hash, Array] contenu JSON de la réponse de l'IA
    # @raise [ExtractionError] clé manquante, API en erreur, réseau ou réponse illisible
    def self.call(messages)
      new(messages).call
    end

    def initialize(messages)
      @messages = messages
    end

    # Les pannes sont traduites ici, au bord de l'objet : l'appelant n'a qu'une
    # seule famille d'erreurs à rattraper.
    def call
      response = post

      unless response.is_a?(Net::HTTPSuccess)
        raise ExtractionError, "Erreur API Claude (#{response.code}) : #{api_error_message(response)}"
      end

      parse_json(answer_text(response))
    rescue JSON::ParserError => e
      raise ExtractionError, "L'IA n'a pas retourné un JSON valide : #{e.message}"
    rescue Net::OpenTimeout, Net::ReadTimeout
      raise ExtractionError, "L'API Claude n'a pas répondu dans les délais impartis"
    rescue ExtractionError
      raise
    rescue => e
      raise ExtractionError, "Erreur inattendue : #{e.message}"
    end

    private

    def post
      uri  = URI.parse(API_URL)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl      = true
      http.open_timeout = OPEN_TIMEOUT
      http.read_timeout = READ_TIMEOUT

      request = Net::HTTP::Post.new(uri.path, {
        "Content-Type"      => "application/json",
        "x-api-key"         => api_key,
        "anthropic-version" => API_VERSION
      })
      request.body = request_body

      http.request(request)
    end

    def request_body
      {
        model:      MODEL,
        max_tokens: MAX_TOKENS,
        system:     ClaudePrompts::SYSTEM,
        messages:   @messages
      }.to_json
    end

    # Réponse de l'API : le contenu utile est le texte du premier bloc.
    def answer_text(response)
      JSON.parse(response.body).dig("content", 0, "text").to_s
    end

    def parse_json(text)
      JSON.parse(text.sub(MARKDOWN_FENCE_OPEN, "").sub(MARKDOWN_FENCE_CLOSE, "").strip)
    end

    # Message d'erreur de l'API : normalement { "error": { "message": … } },
    # mais une panne d'infrastructure peut renvoyer du HTML — on rend alors le
    # corps tel quel plutôt que de masquer la cause.
    def api_error_message(response)
      payload = JSON.parse(response.body)
      (payload.is_a?(Hash) && payload.dig("error", "message")) || response.body
    rescue JSON::ParserError
      response.body
    end

    def api_key
      key = ENV["ANTHROPIC_API_KEY"]
      raise ExtractionError, "Variable ANTHROPIC_API_KEY manquante dans le fichier .env" if key.blank?
      key
    end
  end
end
