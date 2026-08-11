# frozen_string_literal: true

module Recipes
  # Orchestre l'import d'une recette : il décide qui travaille et dans quel
  # ordre, sans rien faire lui-même.
  #
  # Le trajet d'une URL : PageFetcher rapporte la page, SchemaOrgParser la lit,
  # et l'IA n'est sollicitée que pour ce que la page ne dit pas de façon
  # structurée — les ingrédients en texte libre, ou la recette entière quand le
  # site ne publie aucun schema.org. Le dialogue avec l'IA se joue à deux :
  # ClaudePrompts écrit la demande, ClaudeClient la poste.
  class ExtractorService
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
        ClaudeClient.call(ClaudePrompts.text_messages(SchemaOrgParser.extract_text(html)))
      end
    end

    def from_photo(image_base64, media_type:)
      ClaudeClient.call(ClaudePrompts.photo_messages(image_base64, media_type))
    end

    private

    # Construit le hash de retour à partir des données schema.org.
    # Les ingrédients (chaînes brutes) sont les seuls à passer par l'IA.
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
      base["ingredients"] = raw_ingredients.any? ? structure_ingredients(raw_ingredients) : []
      base
    end

    # Demande à l'IA de découper "200 g de farine" en nom, quantité et unité.
    # Un échec dégrade l'import, il ne l'interrompt pas : toute réponse
    # inexploitable — ou absente — laisse place aux chaînes d'origine.
    def structure_ingredients(raw_ingredients)
      structured = ClaudeClient.call(ClaudePrompts.ingredients_messages(raw_ingredients))
      structured.is_a?(Array) ? structured : raw_ingredients_fallback(raw_ingredients)
    rescue ExtractionError
      raw_ingredients_fallback(raw_ingredients)
    end

    # Repli : la chaîne d'origine devient le nom de l'ingrédient, que
    # l'utilisatrice corrigera au moment de la review.
    def raw_ingredients_fallback(raw_ingredients)
      raw_ingredients.map { |ingredient| { "name" => ingredient, "quantity" => nil, "unit" => nil } }
    end
  end
end
