# frozen_string_literal: true

require "rails_helper"

# Spec de Recipes::ExtractorService, né comme filet de sécurité avant le
# découpage du service (étapes 11 et 12) : si un exemple rougit après un
# refactoring, c'est que le comportement a bougé.
#
# Écrits d'abord en tests de caractérisation, ces exemples ont mis au jour six
# bugs, tous corrigés depuis ; chacun garde ici un exemple de non-régression
# marqué « RÉGRESSION » :
#   1. parse_iso_duration ne lisait aucune durée ISO 8601 réelle (préfixe "PT") ;
#   2. format_instructions perdait une étape fournie en Hash unique ;
#   3. recipe_type? rejetait un @type exprimé en URL schema.org complète ;
#   4. parse_schema_org ignorait un objet Recipe nu — la forme la plus courante ;
#   5. `rescue JSON::ParseError` visait une constante inexistante (la vraie est
#      JSON::ParserError) : toute erreur de parse_schema_org ou de call_claude
#      remontait en NameError, donc en 500 puisque le contrôleur ne rattrape
#      qu'ExtractionError ;
#   6. conséquence du point 5, le repli « chaînes brutes » de
#      parse_ingredients_with_claude était inatteignable.
#
# Aucun appel réseau réel n'est fait : ni webmock ni vcr ne sont au Gemfile, on
# intercepte donc Net::HTTP.new pour router chaque connexion vers une réponse
# simulée (voir #stub_http).
#
# NOTE — l'essentiel des méthodes couvertes est privé et appelé via `send`.
# C'est volontairement temporaire : elles deviendront publiques sur les classes
# extraites aux étapes 11 et 12, et les `send` disparaîtront à ce moment-là.
RSpec.describe Recipes::ExtractorService do
  subject(:service) { described_class.new }

  # Requêtes POST reçues par l'API Claude, pour inspecter les prompts envoyés.
  let(:claude_requests) { [] }

  before do
    # Clé d'API présente par défaut : l'exemple qui teste son absence la remet
    # à nil localement.
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:[]).with("ANTHROPIC_API_KEY").and_return("cle-de-test")

    # Réseau scellé par défaut : toute connexion non explicitement simulée par
    # l'exemple lève une erreur bruyante.
    stub_http
  end

  # ── Simulation HTTP ─────────────────────────────────────────────────────

  # Intercepte Net::HTTP.new et route chaque connexion selon l'hôte appelé.
  #   pages  : { "exemple.fr" => réponse } — le GET de fetch_html
  #   claude : réponse unique du POST de call_claude, ou classe d'exception à
  #            lever pour simuler une panne de transport
  def stub_http(pages: {}, claude: nil)
    allow(Net::HTTP).to receive(:new) do |host, _port|
      connection = instance_double(
        Net::HTTP, :use_ssl= => nil, :open_timeout= => nil, :read_timeout= => nil
      )

      if host == "api.anthropic.com"
        allow(connection).to receive(:request) do |request|
          claude_requests << request
          raise claude if claude.is_a?(Class)
          claude || unexpected_request("POST Claude")
        end
      else
        allow(connection).to receive(:get) { pages.fetch(host) { unexpected_request("GET #{host}") } }
      end

      connection
    end
  end

  def unexpected_request(what)
    raise "Requête HTTP non simulée dans cet exemple : #{what}"
  end

  # Fabrique une vraie réponse Net::HTTP : c'est sa *classe* qui porte la
  # famille (succès / redirection / erreur) que le service teste par `case`.
  def http_response(klass, code, body: "", location: nil)
    response = klass.new("1.1", code, code)
    # Le corps est dupliqué : fetch_html appelle force_encoding, qui mute.
    allow(response).to receive(:body).and_return(body.dup)
    allow(response).to receive(:[]).with("location").and_return(location)
    response
  end

  def page_response(html)
    http_response(Net::HTTPOK, "200", body: html)
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

  # ── Fixtures HTML ───────────────────────────────────────────────────────

  # Page portant un ou plusieurs blocs JSON-LD. Chaque bloc accepte un Hash ou
  # un Array (sérialisés), ou une chaîne brute pour simuler un JSON-LD invalide.
  def page_with_json_ld(*blocks)
    scripts = blocks.map do |data|
      payload = data.is_a?(String) ? data : data.to_json
      %(<script type="application/ld+json">#{payload}</script>)
    end

    <<~HTML
      <html>
        <head>#{scripts.join}</head>
        <body><h1>Soupe de potiron</h1><p>Faire revenir le potiron.</p></body>
      </html>
    HTML
  end

  # Forme @graph : un objet racine encapsulant tout le contenu de la page.
  def page_with_graph(recipe)
    page_with_json_ld({ "@context" => "https://schema.org",
                        "@graph"   => [ { "@type" => "WebPage" }, recipe ] })
  end

  # Page sans JSON-LD, avec du bruit (script, style, nav, footer) que
  # extract_text doit retirer avant d'envoyer le texte à Claude.
  def page_without_json_ld
    <<~HTML
      <html>
        <head><script>var analytics = 1;</script><style>.a { color: red; }</style></head>
        <body>
          <nav>Accueil Recettes Connexion</nav>
          <h1>Soupe de potiron</h1>
          <p>Faire revenir le potiron.</p>
          <footer>Mentions legales</footer>
        </body>
      </html>
    HTML
  end

  let(:schema_recipe) do
    {
      "@type"              => "Recipe",
      "name"               => "  Tarte aux poireaux  ",
      "description"        => "  Une tarte salée de saison  ",
      "recipeYield"        => "4-6 personnes",
      "prepTime"           => "PT20M",
      "cookTime"           => "PT40M",
      "totalTime"          => "PT1H",
      "recipeCategory"     => "Plat principal, Tarte",
      "recipeInstructions" => [
        { "@type" => "HowToStep", "text" => "Préchauffer le four." },
        { "@type" => "HowToStep", "text" => "Enfourner 40 minutes." }
      ],
      "recipeIngredient"   => []
    }
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

  # ── parse_yield ─────────────────────────────────────────────────────────

  describe "#parse_yield" do
    def parse_yield(value)
      service.send(:parse_yield, value)
    end

    it "extrait le nombre de parts d'un libellé" do
      expect(parse_yield("4 personnes")).to eq(4)
      expect(parse_yield("Pour 12 mini-cakes")).to eq(12)
    end

    it "retient le dernier nombre d'un intervalle (la borne haute)" do
      expect(parse_yield("4-6 parts")).to eq(6)
    end

    it "accepte une valeur déjà numérique" do
      expect(parse_yield(4)).to eq(4)
    end

    it "retourne nil quand aucun chiffre n'est présent" do
      expect(parse_yield("quelques parts")).to be_nil
    end

    it "retourne nil sur une valeur vide" do
      expect(parse_yield(nil)).to be_nil
      expect(parse_yield("")).to be_nil
    end
  end

  # ── parse_iso_duration ──────────────────────────────────────────────────

  describe "#parse_iso_duration" do
    def parse_iso_duration(value)
      service.send(:parse_iso_duration, value)
    end

    # RÉGRESSION n°1 — la regex a longtemps été entièrement optionnelle : elle
    # matchait la chaîne VIDE dès le préfixe "PT" sans jamais atteindre les
    # chiffres, et aucune durée n'était importée.
    it "convertit les durées ISO 8601 en minutes" do
      expect(parse_iso_duration("PT1H30M")).to eq(90)
      expect(parse_iso_duration("PT45M")).to eq(45)
      expect(parse_iso_duration("PT2H")).to eq(120)
    end

    it "lit aussi la forme longue, partie calendaire comprise" do
      expect(parse_iso_duration("P0DT1H30M")).to eq(90)
    end

    it "retourne nil sur une valeur vide ou non parsable" do
      expect(parse_iso_duration(nil)).to be_nil
      expect(parse_iso_duration("")).to be_nil
      expect(parse_iso_duration("une bonne heure")).to be_nil
      expect(parse_iso_duration("PT0M")).to be_nil
    end
  end

  # ── format_instructions ─────────────────────────────────────────────────

  describe "#format_instructions" do
    def format_instructions(data)
      service.send(:format_instructions, data)
    end

    it "numérote un tableau de Hash en lisant text puis name" do
      steps = [ { "text" => "Préchauffer." }, { "name" => "Enfourner." } ]

      expect(format_instructions(steps)).to eq("1. Préchauffer.\n2. Enfourner.")
    end

    it "numérote un tableau de String" do
      expect(format_instructions([ "Préchauffer.", "Enfourner." ]))
        .to eq("1. Préchauffer.\n2. Enfourner.")
    end

    it "accepte un mélange de Hash et de String et renumérote après filtrage des vides" do
      steps = [ "Préchauffer.", "", { "text" => "   " }, { "text" => "Enfourner." } ]

      expect(format_instructions(steps)).to eq("1. Préchauffer.\n2. Enfourner.")
    end

    it "retourne une chaîne vide sur une donnée vide" do
      expect(format_instructions(nil)).to eq("")
      expect(format_instructions([])).to eq("")
      expect(format_instructions("")).to eq("")
    end

    # RÉGRESSION n°2 — avec Array(), un Hash unique était éclaté en paires
    # clé/valeur qui ne matchaient ni Hash ni String, et l'étape était perdue.
    it "accepte une étape unique fournie hors tableau" do
      expect(format_instructions({ "text" => "Tout mélanger." })).to eq("1. Tout mélanger.")
      expect(format_instructions("Tout mélanger.")).to eq("1. Tout mélanger.")
    end
  end

  # ── recipe_type? ────────────────────────────────────────────────────────

  describe "#recipe_type?" do
    def recipe_type?(data)
      service.send(:recipe_type?, data)
    end

    it "reconnaît un @type string" do
      expect(recipe_type?({ "@type" => "Recipe" })).to be(true)
    end

    it "reconnaît un @type tableau contenant Recipe" do
      expect(recipe_type?({ "@type" => [ "Recipe", "NewsArticle" ] })).to be(true)
    end

    it "rejette un @type qui n'est pas une recette" do
      expect(recipe_type?({ "@type" => "WebPage" })).to be(false)
      expect(recipe_type?({ "@type" => nil })).to be(false)
      expect(recipe_type?({})).to be(false)
    end

    # RÉGRESSION n°3 — la comparaison était stricte, et tous les sites qui
    # déclarent leur type par son URL de vocabulaire étaient ignorés.
    it "reconnaît un @type exprimé en URL schema.org complète" do
      expect(recipe_type?({ "@type" => "http://schema.org/Recipe" })).to be(true)
      expect(recipe_type?({ "@type" => "https://schema.org/Recipe" })).to be(true)
    end

    it "rejette toute donnée qui n'est pas un Hash" do
      expect(recipe_type?("Recipe")).to be(false)
      expect(recipe_type?([ "Recipe" ])).to be(false)
      expect(recipe_type?(nil)).to be(false)
    end
  end

  # ── from_url : chemin schema.org ────────────────────────────────────────

  describe ".from_url avec du schema.org" do
    # RÉGRESSION n°4 — Array(Hash) éclatait l'objet en paires clé/valeur, dont
    # aucune n'est un Hash : la forme la plus courante du schema.org était
    # ignorée et chaque import repartait inutilement vers l'IA.
    it "extrait toute la recette d'un objet Recipe nu, sans appeler Claude" do
      stub_http(pages: { "exemple.fr" => page_response(page_with_json_ld(schema_recipe)) })

      expect(described_class.from_url("https://exemple.fr/tarte")).to eq(extracted_recipe)
      expect(claude_requests).to be_empty
    end

    it "exploite aussi la forme @graph" do
      stub_http(pages: { "exemple.fr" => page_response(page_with_graph(schema_recipe)) })

      expect(described_class.from_url("https://exemple.fr/tarte")).to eq(extracted_recipe)
    end

    it "exploite aussi un tableau JSON-LD racine" do
      page = page_with_json_ld([ { "@type" => "WebPage" }, schema_recipe ])
      stub_http(pages: { "exemple.fr" => page_response(page) })

      expect(described_class.from_url("https://exemple.fr/tarte")).to eq(extracted_recipe)
    end

    it "structure les ingrédients bruts via Claude et tolère les balises markdown" do
      schema = schema_recipe.merge("recipeIngredient" => [ "200 g de farine", "", "3 oeufs" ])
      structured = [
        { "name" => "farine", "quantity" => 200, "unit" => "g" },
        { "name" => "oeufs", "quantity" => 3, "unit" => nil }
      ]
      stub_http(
        pages:  { "exemple.fr" => page_response(page_with_graph(schema)) },
        claude: claude_response("```json\n#{structured.to_json}\n```")
      )

      result = described_class.from_url("https://exemple.fr/tarte")

      expect(result["ingredients"]).to eq(structured)
      # Les ingrédients vides sont retirés avant d'être soumis à l'IA.
      expect(last_claude_prompt).to include("- 200 g de farine", "- 3 oeufs")
      expect(last_claude_prompt).not_to include("- \n")
    end

    it "se rabat sur Claude quand le @graph ne contient aucune recette" do
      ia_result = { "name" => "Soupe de potiron", "ingredients" => [] }
      page = page_with_json_ld({ "@graph" => [ { "@type" => "WebPage" }, { "@type" => "Article" } ] })
      stub_http(
        pages:  { "exemple.fr" => page_response(page) },
        claude: claude_response(ia_result.to_json)
      )

      expect(described_class.from_url("https://exemple.fr/soupe")).to eq(ia_result)
    end

    # RÉGRESSION n°5 — le `rescue JSON::ParseError` visait une constante
    # inexistante : le rescue lui-même levait un NameError, jamais rattrapé par
    # RecipeImportsController, donc une erreur 500 sur toute page portant un
    # bloc JSON-LD malformé (elles sont nombreuses).
    it "ignore un bloc JSON-LD malformé et exploite le suivant" do
      page = page_with_json_ld("{ ceci n'est pas du JSON", schema_recipe)
      stub_http(pages: { "exemple.fr" => page_response(page) })

      expect(described_class.from_url("https://exemple.fr/tarte")).to eq(extracted_recipe)
    end

    it "se rabat sur Claude quand le JSON-LD n'est pas un objet" do
      ia_result = { "name" => "Soupe de potiron", "ingredients" => [] }
      stub_http(
        pages:  { "exemple.fr" => page_response(page_with_json_ld('"un simple texte"')) },
        claude: claude_response(ia_result.to_json)
      )

      expect(described_class.from_url("https://exemple.fr/soupe")).to eq(ia_result)
    end

    it "se rabat sur Claude quand le seul bloc JSON-LD est malformé" do
      ia_result = { "name" => "Soupe de potiron", "ingredients" => [] }
      stub_http(
        pages:  { "exemple.fr" => page_response(page_with_json_ld("{ ceci n'est pas du JSON")) },
        claude: claude_response(ia_result.to_json)
      )

      expect(described_class.from_url("https://exemple.fr/soupe")).to eq(ia_result)
    end
  end

  # ── from_url : repli sur l'extraction IA du texte ───────────────────────

  describe ".from_url sans schema.org" do
    it "envoie à Claude le texte nettoyé de la page" do
      ia_result = { "name" => "Soupe de potiron", "ingredients" => [] }
      stub_http(
        pages:  { "exemple.fr" => page_response(page_without_json_ld) },
        claude: claude_response(ia_result.to_json)
      )

      expect(described_class.from_url("https://exemple.fr/soupe")).to eq(ia_result)

      prompt = last_claude_prompt
      expect(prompt).to include("Soupe de potiron", "Faire revenir le potiron.")
      # script, style, nav et footer sont retirés du texte soumis.
      expect(prompt).not_to include("analytics", "Accueil Recettes", "Mentions legales")
    end

    # Même racine que la RÉGRESSION n°5 : ce message d'erreur était inatteignable.
    it "signale proprement une réponse non JSON de l'IA" do
      stub_http(
        pages:  { "exemple.fr" => page_response(page_without_json_ld) },
        claude: claude_response("Désolé, je ne peux pas lire cette recette.")
      )

      expect { described_class.from_url("https://exemple.fr/soupe") }
        .to raise_error(described_class::ExtractionError, /L'IA n'a pas retourné un JSON valide/)
    end

    it "remonte le message d'erreur de l'API Claude" do
      stub_http(
        pages:  { "exemple.fr" => page_response(page_without_json_ld) },
        claude: claude_error_response("529", "overloaded_error")
      )

      expect { described_class.from_url("https://exemple.fr/soupe") }
        .to raise_error(described_class::ExtractionError, "Erreur API Claude (529) : overloaded_error")
    end

    it "traduit un dépassement de délai de l'API en message dédié" do
      stub_http(
        pages:  { "exemple.fr" => page_response(page_without_json_ld) },
        claude: Net::ReadTimeout
      )

      expect { described_class.from_url("https://exemple.fr/soupe") }
        .to raise_error(described_class::ExtractionError, "L'API Claude n'a pas répondu dans les délais impartis")
    end

    it "enveloppe toute panne de transport inattendue" do
      stub_http(
        pages:  { "exemple.fr" => page_response(page_without_json_ld) },
        claude: Errno::ECONNRESET
      )

      expect { described_class.from_url("https://exemple.fr/soupe") }
        .to raise_error(described_class::ExtractionError, /Erreur inattendue/)
    end

    it "rend le corps brut quand l'erreur de l'API n'est pas du JSON" do
      stub_http(
        pages:  { "exemple.fr" => page_response(page_without_json_ld) },
        claude: http_response(Net::HTTPInternalServerError, "502", body: "<html>Bad Gateway</html>")
      )

      expect { described_class.from_url("https://exemple.fr/soupe") }
        .to raise_error(described_class::ExtractionError, /502.*Bad Gateway/m)
    end
  end

  # ── fetch_html : cas d'erreur ───────────────────────────────────────────

  describe "#fetch_html" do
    it "refuse une URL qui n'est pas en http/https" do
      expect { described_class.from_url("ftp://exemple.fr/tarte") }
        .to raise_error(described_class::ExtractionError, "URL invalide (doit commencer par http/https)")

      expect { described_class.from_url(nil) }
        .to raise_error(described_class::ExtractionError, "URL invalide (doit commencer par http/https)")
    end

    it "refuse une URL syntaxiquement invalide" do
      expect { described_class.from_url("https://exemple .fr/tarte") }
        .to raise_error(described_class::ExtractionError, "URL invalide")
    end

    it "suit une redirection" do
      stub_http(pages: {
        "ancien.fr"  => http_response(Net::HTTPMovedPermanently, "301", location: "https://nouveau.fr/tarte"),
        "nouveau.fr" => page_response(page_with_graph(schema_recipe))
      })

      expect(described_class.from_url("https://ancien.fr/tarte")).to eq(extracted_recipe)
    end

    it "abandonne au-delà de 5 redirections" do
      stub_http(pages: {
        "boucle.fr" => http_response(Net::HTTPFound, "302", location: "https://boucle.fr/tarte")
      })

      expect { described_class.from_url("https://boucle.fr/tarte") }
        .to raise_error(described_class::ExtractionError, "Trop de redirections")
    end

    it "signale un code de réponse non 200" do
      stub_http(pages: { "exemple.fr" => http_response(Net::HTTPNotFound, "404") })

      expect { described_class.from_url("https://exemple.fr/tarte") }
        .to raise_error(described_class::ExtractionError, "URL inaccessible (code 404)")
    end

    it "enveloppe les erreurs réseau" do
      allow(Net::HTTP).to receive(:new).and_raise(SocketError, "getaddrinfo failed")

      expect { described_class.from_url("https://introuvable.fr/tarte") }
        .to raise_error(described_class::ExtractionError, /Impossible d'accéder à l'URL : getaddrinfo failed/)
    end
  end

  # ── from_photo ──────────────────────────────────────────────────────────

  describe ".from_photo" do
    let(:ia_result) { { "name" => "Gratin de courgettes", "ingredients" => [] } }

    it "envoie l'image en base64 avec son media_type et retourne la recette extraite" do
      stub_http(claude: claude_response(ia_result.to_json))

      expect(described_class.from_photo("QUJD", media_type: "image/png")).to eq(ia_result)

      image, text = last_claude_prompt
      expect(image).to eq(
        "type"   => "image",
        "source" => { "type" => "base64", "media_type" => "image/png", "data" => "QUJD" }
      )
      expect(text["text"]).to include("Lis cette photo de recette")
    end

    it "utilise le media_type image/jpeg par défaut" do
      stub_http(claude: claude_response(ia_result.to_json))

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
      stub_http(claude: claude_response(structured.to_json))

      expect(parse_ingredients).to eq(structured)
    end

    # RÉGRESSION n°6 — ce repli était du code mort : son `rescue
    # ExtractionError` ne pouvait pas s'armer, call_claude levant un NameError
    # (RÉGRESSION n°5) avant toute conversion en ExtractionError. Un échec de
    # l'IA doit dégrader l'import, jamais l'interrompre.
    it "retourne les chaînes brutes quand l'API Claude répond en erreur" do
      stub_http(claude: claude_error_response)

      expect(parse_ingredients).to eq(raw_fallback)
    end

    it "retourne les chaînes brutes quand l'IA ne retourne pas du JSON valide" do
      stub_http(claude: claude_response("Je n'ai pas compris."))

      expect(parse_ingredients).to eq(raw_fallback)
    end

    it "retourne les chaînes brutes quand la clé d'API est absente" do
      allow(ENV).to receive(:[]).with("ANTHROPIC_API_KEY").and_return(nil)

      expect(parse_ingredients).to eq(raw_fallback)
    end

    it "retourne les chaînes brutes quand l'IA répond un objet au lieu d'un tableau" do
      stub_http(claude: claude_response({ "ingredients" => [] }.to_json))

      expect(parse_ingredients).to eq(raw_fallback)
    end
  end
end
