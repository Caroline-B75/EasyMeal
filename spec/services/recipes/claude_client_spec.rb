# frozen_string_literal: true

require "rails_helper"

# Spec de Recipes::ClaudeClient, extrait d'ExtractorService avec les exemples
# qui portaient sur le dialogue HTTP avec l'API : ce qu'on envoie, ce qu'on lit
# de la réponse, et la traduction de chaque panne en ExtractionError française.
#
# RÉGRESSION n°5 — `rescue JSON::ParseError` visait une constante inexistante
# (la vraie est JSON::ParserError) : toute réponse illisible de l'IA remontait
# en NameError, donc en 500 puisque le contrôleur ne rattrape qu'ExtractionError.
# L'exemple correspondant est marqué ci-dessous.
#
# Aucun appel réseau réel n'est fait : ni webmock ni vcr ne sont au Gemfile, on
# intercepte donc Net::HTTP.new pour router chaque connexion vers une réponse
# simulée (voir #stub_claude).
RSpec.describe Recipes::ClaudeClient do
  let(:messages) { [ { role: "user", content: "Bonjour" } ] }

  # Requêtes POST reçues par l'API, pour inspecter ce qui est parti.
  let(:claude_requests) { [] }

  before do
    # Clé d'API présente par défaut : l'exemple qui teste son absence la remet
    # à nil localement.
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:[]).with("ANTHROPIC_API_KEY").and_return("cle-de-test")

    # Réseau scellé par défaut : toute connexion non explicitement simulée par
    # l'exemple lève une erreur bruyante.
    stub_claude
  end

  # Intercepte Net::HTTP.new et route la connexion vers une réponse simulée, ou
  # vers une classe d'exception à lever pour simuler une panne de transport.
  def stub_claude(response = nil)
    allow(Net::HTTP).to receive(:new) do
      connection = instance_double(
        Net::HTTP, :use_ssl= => nil, :open_timeout= => nil, :read_timeout= => nil
      )

      allow(connection).to receive(:request) do |request|
        claude_requests << request
        raise response if response.is_a?(Class)
        response || raise("Requête HTTP non simulée dans cet exemple : POST Claude")
      end

      connection
    end
  end

  # Fabrique une vraie réponse Net::HTTP : c'est sa *classe* qui porte la
  # famille (succès / erreur) que le client teste par `is_a?`.
  def http_response(klass, code, body: "")
    response = klass.new("1.1", code, code)
    allow(response).to receive(:body).and_return(body)
    response
  end

  # Réponse d'API Claude : le client lit content[0].text puis analyse ce texte.
  def claude_response(text)
    http_response(Net::HTTPOK, "200", body: { content: [ { text: text } ] }.to_json)
  end

  def claude_error_response(code = "500", message = "overloaded")
    http_response(Net::HTTPInternalServerError, code, body: { error: { message: message } }.to_json)
  end

  # ── Requête envoyée ─────────────────────────────────────────────────────

  describe "requête envoyée" do
    before { stub_claude(claude_response("{}")) }

    it "poste les messages reçus avec le modèle, la consigne système et la taille de réponse" do
      described_class.call(messages)

      expect(JSON.parse(claude_requests.last.body)).to eq(
        "model"      => described_class::MODEL,
        "max_tokens" => described_class::MAX_TOKENS,
        "system"     => Recipes::ClaudePrompts::SYSTEM,
        "messages"   => [ { "role" => "user", "content" => "Bonjour" } ]
      )
    end

    it "s'authentifie avec la clé du fichier .env et annonce la version d'API" do
      described_class.call(messages)

      request = claude_requests.last
      expect(request["x-api-key"]).to eq("cle-de-test")
      expect(request["anthropic-version"]).to eq(described_class::API_VERSION)
      expect(request["content-type"]).to eq("application/json")
    end
  end

  # ── Réponse de l'IA ─────────────────────────────────────────────────────

  describe "réponse de l'IA" do
    it "rend le JSON produit par l'IA" do
      stub_claude(claude_response({ "name" => "Soupe de potiron" }.to_json))

      expect(described_class.call(messages)).to eq("name" => "Soupe de potiron")
    end

    # La consigne système interdit les balises markdown, mais l'IA en ajoute
    # quand même : sans ce nettoyage, toute la réponse serait perdue.
    it "tolère les balises markdown autour du JSON" do
      structured = [ { "name" => "farine", "quantity" => 200, "unit" => "g" } ]
      stub_claude(claude_response("```json\n#{structured.to_json}\n```"))

      expect(described_class.call(messages)).to eq(structured)
    end

    # RÉGRESSION n°5 — ce message d'erreur était inatteignable tant que le
    # rescue visait JSON::ParseError.
    it "signale proprement une réponse non JSON de l'IA" do
      stub_claude(claude_response("Désolé, je ne peux pas lire cette recette."))

      expect { described_class.call(messages) }
        .to raise_error(Recipes::ExtractionError, /L'IA n'a pas retourné un JSON valide/)
    end
  end

  # ── Pannes ──────────────────────────────────────────────────────────────

  describe "pannes" do
    it "exige la clé ANTHROPIC_API_KEY" do
      allow(ENV).to receive(:[]).with("ANTHROPIC_API_KEY").and_return(nil)

      expect { described_class.call(messages) }
        .to raise_error(Recipes::ExtractionError, /ANTHROPIC_API_KEY manquante/)
      expect(claude_requests).to be_empty
    end

    it "remonte le message d'erreur de l'API Claude" do
      stub_claude(claude_error_response("529", "overloaded_error"))

      expect { described_class.call(messages) }
        .to raise_error(Recipes::ExtractionError, "Erreur API Claude (529) : overloaded_error")
    end

    it "rend le corps brut quand l'erreur de l'API n'est pas du JSON" do
      stub_claude(http_response(Net::HTTPInternalServerError, "502", body: "<html>Bad Gateway</html>"))

      expect { described_class.call(messages) }
        .to raise_error(Recipes::ExtractionError, /502.*Bad Gateway/m)
    end

    it "traduit un dépassement de délai de l'API en message dédié" do
      stub_claude(Net::ReadTimeout)

      expect { described_class.call(messages) }
        .to raise_error(Recipes::ExtractionError, "L'API Claude n'a pas répondu dans les délais impartis")
    end

    it "enveloppe toute panne de transport inattendue" do
      stub_claude(Errno::ECONNRESET)

      expect { described_class.call(messages) }
        .to raise_error(Recipes::ExtractionError, /Erreur inattendue/)
    end
  end
end
