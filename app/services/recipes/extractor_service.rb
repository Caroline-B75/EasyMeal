require "net/http"
require "json"

module Recipes
  class ExtractorService
    MODEL          = "claude-sonnet-4-6"
    API_URL        = "https://api.anthropic.com/v1/messages"
    MAX_TEXT_CHARS = 8_000
    READ_TIMEOUT   = 60

    class ExtractionError < StandardError; end

    # ── Interface publique ──────────────────────────────────────────

    def self.from_url(url)
      new.from_url(url)
    end

    def self.from_photo(image_base64, media_type: "image/jpeg")
      new.from_photo(image_base64, media_type: media_type)
    end

    def from_url(url)
      html   = fetch_html(url)
      schema = parse_schema_org(html)

      if schema
        extract_from_schema(schema)
      else
        extract_with_claude(text_messages(extract_text(html)))
      end
    end

    def from_photo(image_base64, media_type:)
      extract_with_claude(photo_messages(image_base64, media_type))
    end

    private

    # ── Récupération HTML ───────────────────────────────────────────

    def fetch_html(url, redirect_limit = 5)
      raise ExtractionError, "URL invalide (doit commencer par http/https)" unless url.to_s =~ /\Ahttps?:\/\//i

      uri  = URI.parse(url)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl      = uri.scheme == "https"
      http.open_timeout = 10
      http.read_timeout = 30

      response = http.get(uri.request_uri, "User-Agent" => "Mozilla/5.0 (compatible; EasyMeal/1.0)")

      case response
      when Net::HTTPSuccess
        response.body.force_encoding("UTF-8").scrub
      when Net::HTTPRedirection
        raise ExtractionError, "Trop de redirections" if redirect_limit.zero?
        fetch_html(response["location"], redirect_limit - 1)
      else
        raise ExtractionError, "URL inaccessible (code #{response.code})"
      end
    rescue URI::InvalidURIError
      raise ExtractionError, "URL invalide"
    rescue ExtractionError
      raise
    rescue => e
      raise ExtractionError, "Impossible d'accéder à l'URL : #{e.message}"
    end

    # ── Parsing schema.org ──────────────────────────────────────────

    def parse_schema_org(html)
      doc = Nokogiri::HTML(html)
      doc.css('script[type="application/ld+json"]').each do |script|
        data = JSON.parse(script.content)
        # Certains sites wrappent dans @graph
        data = data["@graph"] if data.is_a?(Hash) && data.key?("@graph")
        recipe = Array(data).flatten.find { |d| recipe_type?(d) }
        return recipe if recipe
      rescue JSON::ParseError
        next
      end
      nil
    end

    def recipe_type?(data)
      return false unless data.is_a?(Hash)
      type = data["@type"]
      Array(type).include?("Recipe")
    end

    # Construit le hash de retour à partir des données schema.org.
    # Les ingrédients (strings brutes) sont envoyés à Claude pour structuration.
    def extract_from_schema(schema)
      base = {
        "name"               => schema["name"]&.strip,
        "description"        => schema["description"]&.strip,
        "default_servings"   => parse_yield(schema["recipeYield"]),
        "prep_time_minutes"  => parse_iso_duration(schema["prepTime"]),
        "cook_time_minutes"  => parse_iso_duration(schema["cookTime"]),
        "total_time_minutes" => parse_iso_duration(schema["totalTime"]),
        "difficulty"         => nil,
        "diet"               => "omnivore",
        "appliance"          => nil,
        "instructions"       => format_instructions(schema["recipeInstructions"]),
        "suggested_tags"     => Array(schema["recipeCategory"]).flat_map { |c| c.split(/[,\/]/) }.map(&:strip).reject(&:blank?),
        "ingredients"        => []
      }

      raw_ingredients = Array(schema["recipeIngredient"]).reject(&:blank?)
      base["ingredients"] = raw_ingredients.any? ? parse_ingredients_with_claude(raw_ingredients) : []
      base
    end

    def parse_yield(value)
      return nil if value.blank?
      # Pour les ranges type "4-6 personnes", on prend le dernier chiffre (le plus grand)
      numbers = value.to_s.scan(/\d+/).map(&:to_i)
      numbers.empty? ? nil : numbers.last
    end

    # Convertit une durée ISO 8601 (ex: "PT1H30M") en minutes.
    def parse_iso_duration(value)
      return nil if value.blank?
      match   = value.to_s.match(/(?:(\d+)H)?(?:(\d+)M)?/)
      hours   = match[1].to_i
      minutes = match[2].to_i
      total   = hours * 60 + minutes
      total > 0 ? total : nil
    end

    def format_instructions(data)
      return "" if data.blank?
      steps = Array(data).filter_map do |step|
        case step
        when Hash   then (step["text"] || step["name"])&.strip
        when String then step.strip
        end
      end.reject(&:blank?)
      steps.each_with_index.map { |step, i| "#{i + 1}. #{step}" }.join("\n")
    end

    def extract_text(html)
      doc = Nokogiri::HTML(html)
      doc.css("script, style, nav, footer, header, aside").remove
      doc.text.gsub(/[ \t]+/, " ").gsub(/\n{3,}/, "\n\n").strip.truncate(MAX_TEXT_CHARS)
    end

    # ── Structuration des ingrédients via Claude ────────────────────
    # Utilisé quand schema.org fournit des strings brutes comme "200 g de farine".

    def parse_ingredients_with_claude(raw_ingredients)
      prompt = <<~PROMPT
        Voici une liste de chaînes d'ingrédients extraites d'une recette. Pour chacune, retourne un objet JSON avec :
        - "name" : nom de l'ingrédient uniquement (sans quantité ni unité)
        - "quantity" : nombre décimal (ou null si non précisé)
        - "unit" : parmi g, kg, ml, cl, L, càc, càs, ou null si en pièces

        Retourne UNIQUEMENT un tableau JSON valide, sans texte avant ou après.

        Ingrédients :
        #{raw_ingredients.map { |i| "- #{i}" }.join("\n")}
      PROMPT

      result = call_claude([ { role: "user", content: prompt } ])
      result.is_a?(Array) ? result : []
    rescue ExtractionError
      # Fallback : retourne les strings brutes si Claude échoue
      raw_ingredients.map { |i| { "name" => i, "quantity" => nil, "unit" => nil } }
    end

    # ── Messages Claude ─────────────────────────────────────────────

    def text_messages(text)
      [{
        role: "user",
        content: <<~PROMPT
          Extrait les informations de cette recette et retourne UNIQUEMENT un JSON valide avec exactement ce format :
          #{json_schema_example}

          Règles strictes :
          - difficulty : "facile", "moyen", "difficile" ou null
          - diet : "omnivore", "vegetarien", "vegan" ou "pescetarien"
          - unit des ingrédients : g, kg, ml, cl, L, càc, càs, ou null (si compté en pièces)
          - total_time_minutes : rempli uniquement si prep_time et cook_time ne sont pas distinguables
          - Ne jamais inventer d'information absente du texte

          Texte de la recette :
          #{text}
        PROMPT
      }]
    end

    def photo_messages(image_base64, media_type)
      [{
        role: "user",
        content: [
          {
            type: "image",
            source: { type: "base64", media_type: media_type, data: image_base64 }
          },
          {
            type: "text",
            text: <<~PROMPT
              Lis cette photo de recette et retourne UNIQUEMENT un JSON valide avec exactement ce format :
              #{json_schema_example}

              Règles strictes :
              - difficulty : "facile", "moyen", "difficile" ou null
              - diet : "omnivore", "vegetarien", "vegan" ou "pescetarien"
              - unit des ingrédients : g, kg, ml, cl, L, càc, càs, ou null (si compté en pièces)
              - total_time_minutes : rempli uniquement si prep_time et cook_time ne sont pas distinguables
              - Ne jamais inventer d'information absente de la photo
            PROMPT
          }
        ]
      }]
    end

    # ── Appel API Claude ────────────────────────────────────────────

    def extract_with_claude(messages)
      call_claude(messages)
    end

    def call_claude(messages)
      uri  = URI.parse(API_URL)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl      = true
      http.open_timeout = 10
      http.read_timeout = READ_TIMEOUT

      request = Net::HTTP::Post.new(uri.path, {
        "Content-Type"      => "application/json",
        "x-api-key"         => api_key,
        "anthropic-version" => "2023-06-01"
      })

      request.body = {
        model:      MODEL,
        max_tokens: 2048,
        system:     "Tu es un assistant expert en cuisine. Tu extrais des informations de recettes. Tu retournes UNIQUEMENT du JSON valide, sans balises markdown, sans texte avant ou après le JSON.",
        messages:   messages
      }.to_json

      response = http.request(request)

      unless response.is_a?(Net::HTTPSuccess)
        error_msg = JSON.parse(response.body).dig("error", "message") rescue response.body
        raise ExtractionError, "Erreur API Claude (#{response.code}) : #{error_msg}"
      end

      raw   = JSON.parse(response.body).dig("content", 0, "text").to_s
      clean = raw.gsub(/\A```(?:json)?\s*/m, "").gsub(/\s*```\z/m, "").strip
      JSON.parse(clean)
    rescue JSON::ParseError => e
      raise ExtractionError, "L'IA n'a pas retourné un JSON valide : #{e.message}"
    rescue Net::OpenTimeout, Net::ReadTimeout
      raise ExtractionError, "L'API Claude n'a pas répondu dans les délais impartis"
    rescue ExtractionError
      raise
    rescue => e
      raise ExtractionError, "Erreur inattendue : #{e.message}"
    end

    def api_key
      key = ENV["ANTHROPIC_API_KEY"]
      raise ExtractionError, "Variable ANTHROPIC_API_KEY manquante dans le fichier .env" if key.blank?
      key
    end

    def json_schema_example
      JSON.generate(
        name: "Nom de la recette",
        description: "Description courte et appétissante",
        default_servings: 4,
        prep_time_minutes: 20,
        cook_time_minutes: 40,
        total_time_minutes: nil,
        difficulty: "facile",
        diet: "omnivore",
        appliance: "four",
        instructions: "1. Étape une.\n2. Étape deux.",
        suggested_tags: [ "entrée", "plat" ],
        ingredients: [
          { name: "farine", quantity: 200, unit: "g" },
          { name: "oeufs", quantity: 3, unit: nil }
        ]
      )
    end
  end
end
