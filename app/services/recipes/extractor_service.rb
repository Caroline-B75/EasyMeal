require "net/http"
require "json"

module Recipes
  # Orchestre l'import d'une recette et dialogue avec l'IA.
  #
  # Le trajet d'une URL : PageFetcher rapporte la page, SchemaOrgParser la lit,
  # et Claude n'est sollicité que pour ce que la page ne dit pas de façon
  # structurée — les ingrédients en texte libre, ou la recette entière quand le
  # site ne publie aucun schema.org.
  class ExtractorService
    MODEL        = "claude-sonnet-4-6"
    API_URL      = "https://api.anthropic.com/v1/messages"
    READ_TIMEOUT = 60

    # ── Interface publique ──────────────────────────────────────────

    def self.from_url(url)
      new.from_url(url)
    end

    def self.from_photo(image_base64, media_type: "image/jpeg")
      new.from_photo(image_base64, media_type: media_type)
    end

    def from_url(url)
      html   = PageFetcher.call(url)
      schema = SchemaOrgParser.parse_schema_org(html)

      if schema
        extract_from_schema(schema)
      else
        extract_with_claude(text_messages(SchemaOrgParser.extract_text(html)))
      end
    end

    def from_photo(image_base64, media_type:)
      extract_with_claude(photo_messages(image_base64, media_type))
    end

    private

    # Construit le hash de retour à partir des données schema.org.
    # Les ingrédients (strings brutes) sont envoyés à Claude pour structuration.
    def extract_from_schema(schema)
      base = {
        "name"               => schema["name"]&.strip,
        "description"        => schema["description"]&.strip,
        "default_servings"   => SchemaOrgParser.parse_yield(schema["recipeYield"]),
        "prep_time_minutes"  => SchemaOrgParser.parse_iso_duration(schema["prepTime"]),
        "cook_time_minutes"  => SchemaOrgParser.parse_iso_duration(schema["cookTime"]),
        "total_time_minutes" => SchemaOrgParser.parse_iso_duration(schema["totalTime"]),
        "difficulty"         => nil,
        "diet"               => "omnivore",
        "appliance"          => nil,
        "instructions"       => SchemaOrgParser.format_instructions(schema["recipeInstructions"]),
        "suggested_tags"     => SchemaOrgParser.parse_categories(schema["recipeCategory"]),
        "ingredients"        => []
      }

      raw_ingredients = Array.wrap(schema["recipeIngredient"]).reject(&:blank?)
      base["ingredients"] = raw_ingredients.any? ? parse_ingredients_with_claude(raw_ingredients) : []
      base
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
      # Toute réponse qui n'est pas un tableau est inexploitable : on garde le brut.
      result.is_a?(Array) ? result : raw_ingredients_fallback(raw_ingredients)
    rescue ExtractionError
      raw_ingredients_fallback(raw_ingredients)
    end

    # Repli quand l'IA n'a pas structuré la liste : la chaîne d'origine devient
    # le nom de l'ingrédient, que l'utilisatrice corrigera au moment de la review.
    def raw_ingredients_fallback(raw_ingredients)
      raw_ingredients.map { |ingredient| { "name" => ingredient, "quantity" => nil, "unit" => nil } }
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
        raise ExtractionError, "Erreur API Claude (#{response.code}) : #{api_error_message(response)}"
      end

      raw   = JSON.parse(response.body).dig("content", 0, "text").to_s
      clean = raw.gsub(/\A```(?:json)?\s*/m, "").gsub(/\s*```\z/m, "").strip
      JSON.parse(clean)
    rescue JSON::ParserError => e
      raise ExtractionError, "L'IA n'a pas retourné un JSON valide : #{e.message}"
    rescue Net::OpenTimeout, Net::ReadTimeout
      raise ExtractionError, "L'API Claude n'a pas répondu dans les délais impartis"
    rescue ExtractionError
      raise
    rescue => e
      raise ExtractionError, "Erreur inattendue : #{e.message}"
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
