# frozen_string_literal: true

module Recipes
  # Orchestre l'import d'une recette : il décide qui travaille et dans quel
  # ordre, sans rien faire lui-même.
  #
  # Le trajet d'une URL : PageFetcher rapporte la page, SchemaOrgParser la lit,
  # et l'IA n'est sollicitée que pour ce que la page ne dit pas de façon
  # structurée — les ingrédients en texte libre et le classement de la recette,
  # ou la recette entière quand le site ne publie aucun schema.org. Le dialogue
  # avec l'IA se joue à deux :
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

      data = if schema
        extract_from_schema(schema)
      else
        ClaudeClient.call(ClaudePrompts.text_request(SchemaOrgParser.extract_text(html)))
      end

      canonical_units(data)
    end

    def from_photo(image_base64, media_type:)
      canonical_units(ClaudeClient.call(ClaudePrompts.photo_request(image_base64, media_type)))
    end

    private

    # Ce que l'IA ajoute à une page qui publie déjà ses faits : des ingrédients
    # structurés, et un classement (moments, budget, difficulté, régime, tags)
    # qu'aucun schema.org ne donne.
    CLASSIFICATION_KEYS = %w[difficulty diet price meal_types tags].freeze

    # Construit le hash de retour à partir des données schema.org.
    def extract_from_schema(schema)
      base = {
        "name"               => schema["name"]&.strip,
        "description"        => schema["description"]&.strip,
        "default_servings"   => SchemaOrgParser.parse_yield(schema["recipeYield"]),
        "prep_time_minutes"  => SchemaOrgParser.parse_iso_duration(schema["prepTime"]),
        "cook_time_minutes"  => SchemaOrgParser.parse_iso_duration(schema["cookTime"]),
        "total_time_minutes" => SchemaOrgParser.parse_iso_duration(schema["totalTime"]),
        "appliance"          => nil,
        "instructions"       => SchemaOrgParser.format_instructions(schema["recipeInstructions"]),
        # Valeurs de repli du classement : elles restent en place si l'IA échoue.
        "difficulty"         => nil,
        "diet"               => nil,
        "price"              => nil,
        "meal_types"         => [],
        "tags"               => [],
        "ingredients"        => []
      }

      base.merge(structure_and_classify(base, schema))
    end

    # Un seul appel à l'IA pour les deux manques de la page : « 200 g de farine »
    # à découper en nom, quantité et unité, et la recette à classer.
    #
    # Un échec dégrade l'import, il ne l'interrompt pas : toute réponse
    # inexploitable — ou absente — laisse place aux chaînes d'origine et à un
    # classement vide, que l'utilisatrice complétera à la validation.
    def structure_and_classify(base, schema)
      raw_ingredients = Array.wrap(schema["recipeIngredient"]).reject(&:blank?)

      answer = ClaudeClient.call(ClaudePrompts.schema_org_request(
        name:         base["name"],
        description:  base["description"],
        categories:   SchemaOrgParser.parse_categories(schema["recipeCategory"]),
        instructions: base["instructions"],
        ingredients:  raw_ingredients
      ))
      return { "ingredients" => raw_ingredients_fallback(raw_ingredients) } unless answer.is_a?(Hash)

      answer.slice(*CLASSIFICATION_KEYS)
            .merge("ingredients" => structured_ingredients(answer, raw_ingredients))
    rescue ExtractionError
      { "ingredients" => raw_ingredients_fallback(raw_ingredients) }
    end

    # La racine d'un schéma étant un objet, le tableau attendu arrive sous la
    # clé "ingredients" : on le déballe ici.
    def structured_ingredients(answer, raw_ingredients)
      structured = answer["ingredients"]

      structured.is_a?(Array) ? structured : raw_ingredients_fallback(raw_ingredients)
    end

    # Repli : la chaîne d'origine devient le nom de l'ingrédient, que
    # l'utilisatrice corrigera au moment de la review.
    def raw_ingredients_fallback(raw_ingredients)
      raw_ingredients.map { |ingredient| { "name" => ingredient, "quantity" => nil, "unit" => nil } }
    end

    # Le vocabulaire verbeux imposé à l'IA (« cuillere_a_soupe ») rejoint ici les
    # unités canoniques du projet, une fois pour toutes : ni le brouillon
    # (ai_raw_data), ni le panneau de revue, ni la conversion n'ont à connaître la
    # façon dont l'IA parle des cuillères. Le passage est unique parce que les
    # trois chemins d'extraction se referment ici.
    #
    # Une unité que Units ne sait pas lire est laissée telle quelle : la revue la
    # montrera et signalera qu'elle ne se convertit pas, plutôt que de l'effacer
    # en silence.
    def canonical_units(data)
      ingredients = data.is_a?(Hash) ? data["ingredients"] : nil
      return data unless ingredients.is_a?(Array)

      data.merge("ingredients" => ingredients.map { |ingredient| canonical_unit(ingredient) })
    end

    def canonical_unit(ingredient)
      return ingredient unless ingredient.is_a?(Hash) && ingredient["unit"].present?

      ingredient.merge("unit" => Units.canonical(ingredient["unit"]) || ingredient["unit"])
    end
  end
end
