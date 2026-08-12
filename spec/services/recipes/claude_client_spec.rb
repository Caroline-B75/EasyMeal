# frozen_string_literal: true

require "rails_helper"
require "webmock/rspec"

# WebMock scelle le réseau pour toute la suite dès qu'il est chargé ; localhost
# reste ouvert pour d'éventuels tests de bout en bout.
WebMock.disable_net_connect!(allow_localhost: true)

# Spec de Recipes::ClaudeClient : ce qu'on envoie à l'API Anthropic, ce qu'on
# lit de sa réponse, et la traduction de chaque panne en ExtractionError
# française.
#
# Le SDK officiel poste lui-même la requête : on simule donc l'API au niveau
# HTTP plutôt que les objets du SDK. Le corps réellement envoyé est ainsi
# vérifiable, et ce sont les réponses simulées qui font lever au SDK ses vraies
# exceptions typées — c'est bien leur traduction qui est testée ici.
#
# RÉGRESSION n°5 — `rescue JSON::ParseError` visait une constante inexistante
# (la vraie est JSON::ParserError) : toute réponse illisible de l'IA remontait
# en NameError, donc en 500 puisque le contrôleur ne rattrape qu'ExtractionError.
# L'exemple correspondant est marqué ci-dessous.
RSpec.describe Recipes::ClaudeClient do
  let(:endpoint) { "https://api.anthropic.com/v1/messages" }

  let(:schema) do
    {
      type:                 "object",
      properties:           { name: { type: "string" } },
      required:             [ "name" ],
      additionalProperties: false
    }
  end
  let(:request) { { messages: [ { role: "user", content: "Bonjour" } ], schema: schema } }

  # Requêtes POST reçues par l'API, pour inspecter ce qui est parti.
  let(:claude_requests) { [] }

  # Clé d'API présente par défaut : l'exemple qui teste son absence la remet
  # à nil localement.
  before do
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:[]).with("ANTHROPIC_API_KEY").and_return("cle-de-test")
  end

  # Simule l'API Claude ; le bloc dit ce qu'elle répond (`to_return`,
  # `to_timeout`, `to_raise`). Le `with` sert de mouchard : il enregistre la
  # requête reçue et l'accepte toujours.
  def stub_claude
    yield stub_request(:post, endpoint).with { |request| claude_requests << request }
  end

  # Réponse de l'API : le JSON demandé arrive dans le bloc de texte du message.
  def claude_response(text)
    {
      status:  200,
      headers: { "Content-Type" => "application/json" },
      body:    {
        id:          "msg_test",
        type:        "message",
        role:        "assistant",
        model:       described_class::MODEL,
        content:     [ { type: "text", text: text } ],
        stop_reason: "end_turn",
        usage:       { input_tokens: 10, output_tokens: 20 }
      }.to_json
    }
  end

  def claude_error_response(status, message)
    {
      status:  status,
      headers: { "Content-Type" => "application/json" },
      body:    { type: "error", error: { type: "overloaded_error", message: message } }.to_json
    }
  end

  def last_request_body
    JSON.parse(claude_requests.last.body)
  end

  # ── Requête envoyée ─────────────────────────────────────────────────────

  describe "requête envoyée" do
    before { stub_claude { |api| api.to_return(**claude_response("{}")) } }

    it "poste les messages reçus avec le modèle, la consigne système et la taille de réponse" do
      described_class.call(request)

      expect(last_request_body).to include(
        "model"      => described_class::MODEL,
        "max_tokens" => described_class::MAX_TOKENS,
        "system"     => Recipes::ClaudePrompts::SYSTEM,
        "messages"   => [ { "role" => "user", "content" => "Bonjour" } ],
        # L'extraction n'a rien à méditer : réfléchir coûterait de l'attente et
        # grignoterait les tokens de la réponse.
        "thinking"   => { "type" => "disabled" }
      )
    end

    # Le contrat qui remplace les supplications du prompt : le schéma part avec
    # la requête, l'API garantit que la réponse s'y conforme.
    it "impose à l'IA le schéma de sortie reçu" do
      described_class.call(request)

      expect(last_request_body["output_config"]).to eq(
        "format" => { "type" => "json_schema", "schema" => schema.deep_stringify_keys }
      )
    end

    it "s'authentifie avec la clé du fichier .env et annonce la version d'API" do
      described_class.call(request)

      headers = claude_requests.last.headers
      expect(headers["X-Api-Key"]).to eq("cle-de-test")
      expect(headers["Anthropic-Version"]).to eq("2023-06-01")
      expect(headers["Content-Type"]).to eq("application/json")
    end
  end

  # ── Réponse de l'IA ─────────────────────────────────────────────────────

  describe "réponse de l'IA" do
    it "rend le JSON produit par l'IA" do
      stub_claude { |api| api.to_return(**claude_response({ "name" => "Soupe de potiron" }.to_json)) }

      expect(described_class.call(request)).to eq("name" => "Soupe de potiron")
    end

    # RÉGRESSION n°5 — ce message d'erreur était inatteignable tant que le
    # rescue visait JSON::ParseError. Les sorties structurées garantissent un
    # JSON conforme, mais pas qu'il tienne dans max_tokens : une réponse coupée
    # reste possible, et ne doit pas finir en 500.
    it "signale proprement une réponse tronquée de l'IA" do
      stub_claude { |api| api.to_return(**claude_response('{ "name": "Soupe de po')) }

      expect { described_class.call(request) }
        .to raise_error(Recipes::ExtractionError, /L'IA n'a pas retourné un JSON valide/)
    end
  end

  # ── Pannes ──────────────────────────────────────────────────────────────

  describe "pannes" do
    # Le SDK réessaie tout seul les 429 et 5xx : on lui coupe ses tentatives
    # pour ne pas payer ses temporisations à chaque exemple.
    before { stub_const("#{described_class}::MAX_RETRIES", 0) }

    it "exige la clé ANTHROPIC_API_KEY" do
      allow(ENV).to receive(:[]).with("ANTHROPIC_API_KEY").and_return(nil)

      expect { described_class.call(request) }
        .to raise_error(Recipes::ExtractionError, /ANTHROPIC_API_KEY manquante/)
      expect(a_request(:post, endpoint)).not_to have_been_made
    end

    it "remonte le message d'erreur de l'API Claude" do
      stub_claude { |api| api.to_return(**claude_error_response(529, "overloaded_error")) }

      expect { described_class.call(request) }
        .to raise_error(Recipes::ExtractionError, "Erreur API Claude (529) : overloaded_error")
    end

    # Une panne d'infrastructure répond parfois une page HTML : le message doit
    # rester lisible plutôt que d'exhiber un corps que le SDK n'a pas analysé.
    it "s'en tient au code de statut quand l'erreur de l'API n'est pas du JSON" do
      stub_claude do |api|
        api.to_return(status: 502, headers: { "Content-Type" => "text/html" }, body: "<html>Bad Gateway</html>")
      end

      expect { described_class.call(request) }
        .to raise_error(Recipes::ExtractionError, "Erreur API Claude (502) : réponse inattendue de l'API")
    end

    it "traduit un dépassement de délai de l'API en message dédié" do
      stub_claude(&:to_timeout)

      expect { described_class.call(request) }
        .to raise_error(Recipes::ExtractionError, "L'API Claude n'a pas répondu dans les délais impartis")
    end

    it "signale une API injoignable" do
      stub_claude { |api| api.to_raise(Errno::ECONNRESET) }

      expect { described_class.call(request) }
        .to raise_error(Recipes::ExtractionError, /Impossible de joindre l'API Claude/)
    end
  end
end
