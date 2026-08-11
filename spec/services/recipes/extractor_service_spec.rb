# frozen_string_literal: true

require "rails_helper"
require_relative "../../support/recipe_page_fixtures"

# Spec de Recipes::ExtractorService, né comme filet de sécurité avant le
# découpage du service : si un exemple rougit après un refactoring, c'est que le
# comportement a bougé.
#
# Le HTTP vers les sites de recettes et la lecture des pages ont quitté ce
# service : ils vivent désormais dans PageFetcher et SchemaOrgParser, chacun
# avec sa propre spec. Ne restent ici que l'orchestration et le dialogue avec
# Claude.
#
# Écrits d'abord en tests de caractérisation, ces exemples ont mis au jour six
# bugs, tous corrigés depuis ; les deux qui touchaient au dialogue avec l'IA
# gardent ici un exemple de non-régression marqué « RÉGRESSION » (les quatre
# autres sont passés dans schema_org_parser_spec.rb avec leur méthode) :
#   5. `rescue JSON::ParseError` visait une constante inexistante (la vraie est
#      JSON::ParserError) : toute erreur de call_claude remontait en NameError,
#      donc en 500 puisque le contrôleur ne rattrape qu'ExtractionError ;
#   6. conséquence du point 5, le repli « chaînes brutes » de
#      parse_ingredients_with_claude était inatteignable.
#
# Aucun appel réseau réel n'est fait : ni webmock ni vcr ne sont au Gemfile, on
# intercepte donc Net::HTTP.new pour router chaque connexion vers une réponse
# simulée (voir #stub_claude).
#
# NOTE — parse_ingredients_with_claude reste privé et appelé via `send` : il
# deviendra public sur la classe extraite à l'étape 12, et le `send` disparaîtra
# à ce moment-là.
RSpec.describe Recipes::ExtractorService do
  include RecipePageFixtures

  subject(:service) { described_class.new }

  let(:url) { "https://exemple.fr/recette" }

  # Requêtes POST reçues par l'API Claude, pour inspecter les prompts envoyés.
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

  # ── Simulation des collaborateurs ───────────────────────────────────────

  # Le service ne fait plus qu'un seul appel réseau en propre, celui de l'API
  # Claude : on intercepte Net::HTTP.new pour le router vers une réponse
  # simulée, ou vers une classe d'exception à lever pour simuler une panne de
  # transport.
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

  # La récupération de la page relève de PageFetcher, testé pour lui-même :
  # ici on lui substitue la page voulue. Le `with(url)` vérifie au passage que
  # le service lui transmet bien l'URL reçue.
  def stub_page(html)
    allow(Recipes::PageFetcher).to receive(:call).with(url).and_return(html)
  end

  # Fabrique une vraie réponse Net::HTTP : c'est sa *classe* qui porte la
  # famille (succès / erreur) que le service teste par `is_a?`.
  def http_response(klass, code, body: "")
    response = klass.new("1.1", code, code)
    allow(response).to receive(:body).and_return(body)
    response
  end

  # Réponse d'API Claude : le service lit content[0].text puis parse ce texte.
  def claude_response(text)
    http_response(Net::HTTPOK, "200", body: { content: [ { text: text } ] }.to_json)
  end

  def claude_error_response(code = "500", message = "overloaded")
    http_response(Net::HTTPInternalServerError, code, body: { error: { message: message } }.to_json)
  end

  # Prompt effectivement envoyé à Claude lors du dernier appel.
  def last_claude_prompt
    JSON.parse(claude_requests.last.body).dig("messages", 0, "content")
  end

  # Recette telle que le service la reconstruit depuis schema_recipe.
  let(:extracted_recipe) do
    {
      "name"               => "Tarte aux poireaux",
      "description"        => "Une tarte salée de saison",
      "default_servings"   => 6,
      "prep_time_minutes"  => 20,
      "cook_time_minutes"  => 40,
      "total_time_minutes" => 60,
      "difficulty"         => nil,
      "diet"               => "omnivore",
      "appliance"          => nil,
      "instructions"       => "1. Préchauffer le four.\n2. Enfourner 40 minutes.",
      "suggested_tags"     => [ "Plat principal", "Tarte" ],
      "ingredients"        => []
    }
  end

  # ── from_url : chemin schema.org ────────────────────────────────────────

  describe ".from_url avec du schema.org" do
    it "reconstruit toute la recette depuis le schema.org, sans appeler Claude" do
      stub_page(page_with_json_ld(schema_recipe))

      expect(described_class.from_url(url)).to eq(extracted_recipe)
      expect(claude_requests).to be_empty
    end

    it "structure les ingrédients bruts via Claude et tolère les balises markdown" do
      schema     = schema_recipe.merge("recipeIngredient" => [ "200 g de farine", "", "3 oeufs" ])
      structured = [
        { "name" => "farine", "quantity" => 200, "unit" => "g" },
        { "name" => "oeufs", "quantity" => 3, "unit" => nil }
      ]
      stub_page(page_with_json_ld(schema))
      stub_claude(claude_response("```json\n#{structured.to_json}\n```"))

      result = described_class.from_url(url)

      expect(result["ingredients"]).to eq(structured)
      # Les ingrédients vides sont retirés avant d'être soumis à l'IA.
      expect(last_claude_prompt).to include("- 200 g de farine", "- 3 oeufs")
      expect(last_claude_prompt).not_to include("- \n")
    end
  end

  # ── from_url : repli sur l'extraction IA du texte ───────────────────────

  describe ".from_url sans schema.org" do
    let(:ia_result) { { "name" => "Soupe de potiron", "ingredients" => [] } }

    before { stub_page(page_without_json_ld) }

    it "envoie à Claude le texte nettoyé de la page" do
      stub_claude(claude_response(ia_result.to_json))

      expect(described_class.from_url(url)).to eq(ia_result)

      prompt = last_claude_prompt
      expect(prompt).to include("Soupe de potiron", "Faire revenir le potiron.")
      # C'est le texte extrait qui part dans le prompt, pas le HTML brut.
      expect(prompt).not_to include("analytics", "Accueil Recettes", "Mentions legales")
    end

    # RÉGRESSION n°5 — ce message d'erreur était inatteignable tant que le
    # rescue visait JSON::ParseError.
    it "signale proprement une réponse non JSON de l'IA" do
      stub_claude(claude_response("Désolé, je ne peux pas lire cette recette."))

      expect { described_class.from_url(url) }
        .to raise_error(Recipes::ExtractionError, /L'IA n'a pas retourné un JSON valide/)
    end

    it "remonte le message d'erreur de l'API Claude" do
      stub_claude(claude_error_response("529", "overloaded_error"))

      expect { described_class.from_url(url) }
        .to raise_error(Recipes::ExtractionError, "Erreur API Claude (529) : overloaded_error")
    end

    it "traduit un dépassement de délai de l'API en message dédié" do
      stub_claude(Net::ReadTimeout)

      expect { described_class.from_url(url) }
        .to raise_error(Recipes::ExtractionError, "L'API Claude n'a pas répondu dans les délais impartis")
    end

    it "enveloppe toute panne de transport inattendue" do
      stub_claude(Errno::ECONNRESET)

      expect { described_class.from_url(url) }
        .to raise_error(Recipes::ExtractionError, /Erreur inattendue/)
    end

    it "rend le corps brut quand l'erreur de l'API n'est pas du JSON" do
      stub_claude(http_response(Net::HTTPInternalServerError, "502", body: "<html>Bad Gateway</html>"))

      expect { described_class.from_url(url) }
        .to raise_error(Recipes::ExtractionError, /502.*Bad Gateway/m)
    end
  end

  # ── from_photo ──────────────────────────────────────────────────────────

  describe ".from_photo" do
    let(:ia_result) { { "name" => "Gratin de courgettes", "ingredients" => [] } }

    it "envoie l'image en base64 avec son media_type et retourne la recette extraite" do
      stub_claude(claude_response(ia_result.to_json))

      expect(described_class.from_photo("QUJD", media_type: "image/png")).to eq(ia_result)

      image, text = last_claude_prompt
      expect(image).to eq(
        "type"   => "image",
        "source" => { "type" => "base64", "media_type" => "image/png", "data" => "QUJD" }
      )
      expect(text["text"]).to include("Lis cette photo de recette")
    end

    it "utilise le media_type image/jpeg par défaut" do
      stub_claude(claude_response(ia_result.to_json))

      described_class.from_photo("QUJD")

      expect(last_claude_prompt.first.dig("source", "media_type")).to eq("image/jpeg")
    end
  end

  # ── parse_ingredients_with_claude ───────────────────────────────────────

  describe "#parse_ingredients_with_claude" do
    let(:raw_ingredients) { [ "200 g de farine", "3 oeufs" ] }
    let(:raw_fallback) do
      [
        { "name" => "200 g de farine", "quantity" => nil, "unit" => nil },
        { "name" => "3 oeufs", "quantity" => nil, "unit" => nil }
      ]
    end

    def parse_ingredients
      service.send(:parse_ingredients_with_claude, raw_ingredients)
    end

    it "retourne le tableau structuré par l'IA" do
      structured = [ { "name" => "farine", "quantity" => 200, "unit" => "g" } ]
      stub_claude(claude_response(structured.to_json))

      expect(parse_ingredients).to eq(structured)
    end

    # RÉGRESSION n°6 — ce repli était du code mort : son `rescue
    # ExtractionError` ne pouvait pas s'armer, call_claude levant un NameError
    # (RÉGRESSION n°5) avant toute conversion en ExtractionError. Un échec de
    # l'IA doit dégrader l'import, jamais l'interrompre.
    it "retourne les chaînes brutes quand l'API Claude répond en erreur" do
      stub_claude(claude_error_response)

      expect(parse_ingredients).to eq(raw_fallback)
    end

    it "retourne les chaînes brutes quand l'IA ne retourne pas du JSON valide" do
      stub_claude(claude_response("Je n'ai pas compris."))

      expect(parse_ingredients).to eq(raw_fallback)
    end

    it "retourne les chaînes brutes quand la clé d'API est absente" do
      allow(ENV).to receive(:[]).with("ANTHROPIC_API_KEY").and_return(nil)

      expect(parse_ingredients).to eq(raw_fallback)
    end

    it "retourne les chaînes brutes quand l'IA répond un objet au lieu d'un tableau" do
      stub_claude(claude_response({ "ingredients" => [] }.to_json))

      expect(parse_ingredients).to eq(raw_fallback)
    end
  end
end
