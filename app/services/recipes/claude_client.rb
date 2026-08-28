# frozen_string_literal: true

require "json"

module Recipes
  # Poste une demande à l'API Claude et rend le JSON de sa réponse, déjà analysé.
  #
  # C'est le seul objet de l'import qui parle à l'API Anthropic, et il ne sait
  # rien des recettes : ce qu'on demande à l'IA — les messages et le schéma de
  # sortie — est écrit par ClaudePrompts. Toute panne — clé absente, erreur
  # d'API, réseau muet — ressort en ExtractionError, déjà rédigée en français
  # pour l'utilisatrice.
  #
  # Le format de la réponse n'est plus supplié dans le prompt puis rattrapé à
  # l'analyse : le schéma part avec la requête (sorties structurées) et l'API
  # garantit que la réponse s'y conforme. Rien à gratter, rien à deviner.
  #
  # @example
  #   Recipes::ClaudeClient.call(Recipes::ClaudePrompts.text_request(text))
  class ClaudeClient
    MODEL      = "claude-sonnet-5"
    MAX_TOKENS = 8192

    # L'import est synchrone : l'utilisatrice attend devant son formulaire. On
    # borne donc l'appel, le SDK laissant sinon courir jusqu'à 10 minutes.
    TIMEOUT = 60

    # Nouvelles tentatives du SDK sur les 429 et 5xx (sa valeur par défaut,
    # écrite ici pour qu'elle se voie) : inutile de réimplémenter un retry.
    MAX_RETRIES = 2

    # Extraire une recette ne demande pas de raisonnement préalable, et Sonnet 5
    # réfléchit par défaut : on le désactive pour ne pas rallonger l'attente ni
    # amputer les 8192 tokens de la réponse — c'est ce plafond qui tronquait les
    # recettes longues.
    THINKING = { type: "disabled" }.freeze

    # @param request [Hash] { messages:, schema:, system: } construit par un
    #   objet de prompt (Recipes::ClaudePrompts, Ingredients::DensityPrompt)
    # @return [Hash] contenu JSON de la réponse de l'IA, conforme au schéma
    # @raise [ExtractionError] clé manquante, API en erreur, réseau ou réponse illisible
    def self.call(request)
      new(request).call
    end

    def initialize(request)
      @messages = request.fetch(:messages)
      @schema   = request.fetch(:schema)
      # Consigne système propre à la demande quand elle en porte une : toutes ne
      # parlent pas d'extraire une recette.
      @system   = request.fetch(:system, ClaudePrompts::SYSTEM)
    end

    # Les pannes sont traduites ici, au bord de l'objet : l'appelant n'a qu'une
    # seule famille d'erreurs à rattraper.
    def call
      JSON.parse(answer_text(post))
    rescue JSON::ParserError => e
      # Le schéma garantit un JSON conforme, mais pas qu'il tienne dans
      # MAX_TOKENS : une recette hors norme peut encore arriver coupée.
      raise ExtractionError, "L'IA n'a pas retourné un JSON valide : #{e.message}"
    rescue Anthropic::Errors::APIStatusError => e
      raise ExtractionError, "Erreur API Claude (#{e.status}) : #{api_error_message(e)}"
    rescue Anthropic::Errors::APITimeoutError
      raise ExtractionError, "L'API Claude n'a pas répondu dans les délais impartis"
    rescue Anthropic::Errors::APIConnectionError => e
      raise ExtractionError, "Impossible de joindre l'API Claude : #{e.message}"
    rescue ExtractionError
      raise
    rescue => e
      raise ExtractionError, "Erreur inattendue : #{e.message}"
    end

    private

    def post
      client.messages.create(
        model:           MODEL,
        max_tokens:      MAX_TOKENS,
        thinking:        THINKING,
        system_:         @system,
        messages:        @messages,
        output_config:   { format_: { type: :json_schema, schema: @schema } },
        # Le délai se pose sur la requête : posé sur le client, le SDK le
        # remplacerait par le sien au moment de l'appel.
        request_options: { timeout: TIMEOUT }
      )
    end

    # Un client neuf par appel : l'import ne poste qu'une requête à la fois, et
    # la clé est ainsi relue à chaque fois plutôt que figée au démarrage.
    def client
      Anthropic::Client.new(api_key: api_key, max_retries: MAX_RETRIES)
    end

    # Le JSON demandé arrive dans le bloc de texte de la réponse.
    def answer_text(message)
      message.content.select { |block| block.type == :text }.map(&:text).join
    end

    # Corps d'erreur de l'API : { "error": { "message": … } }, analysé par le SDK
    # en clés symboles. Une panne d'infrastructure répond parfois autre chose
    # (page HTML d'un proxy, corps vide) que le SDK laisse alors non analysé :
    # le code de statut est tout ce qu'on peut dire d'utile.
    def api_error_message(error)
      body = error.body
      (body.is_a?(Hash) && body.dig(:error, :message).presence) || "réponse inattendue de l'API"
    end

    # Le SDK lirait ANTHROPIC_API_KEY tout seul, mais irait ensuite chercher
    # d'autres identifiants sur le poste : on la vérifie donc nous-mêmes, pour
    # dire franchement ce qui manque.
    def api_key
      key = ENV["ANTHROPIC_API_KEY"]
      raise ExtractionError, "Variable ANTHROPIC_API_KEY manquante dans le fichier .env" if key.blank?
      key
    end
  end
end
