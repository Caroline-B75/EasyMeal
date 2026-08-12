# frozen_string_literal: true

module Recipes
  # Écrit ce qu'on demande à l'IA : les trois conversations de l'import — une
  # recette lue dans du texte, une recette lue sur une photo, une liste
  # d'ingrédients bruts à structurer.
  #
  # Chaque méthode rend une demande complète : les `messages` à envoyer et le
  # `schema` JSON auquel la réponse devra se conformer. Les deux voyagent
  # ensemble parce qu'ils se répondent — le prompt dit quoi lire, le schéma dit
  # sous quelle forme le rendre. Et comme l'API fait respecter le second
  # (sorties structurées), le premier n'a plus à mendier du JSON ni à décrire
  # le format attendu : il ne parle que de cuisine.
  #
  # Tout le français adressé à Claude vit ici, et nulle part ailleurs :
  # ClaudeClient se charge de l'envoyer sans rien savoir de son contenu. Rien à
  # porter d'un appel à l'autre, d'où des méthodes de classe plutôt qu'une
  # instance sans état.
  #
  # @example
  #   Recipes::ClaudeClient.call(Recipes::ClaudePrompts.text_request(page_text))
  class ClaudePrompts
    # Consigne système, envoyée à chaque appel.
    SYSTEM = "Tu es un assistant expert en cuisine. Tu extrais des informations de recettes."

    # Unités qu'un ingrédient peut porter. Même table que le panneau
    # « Ingrédients détectés par l'IA » (ai_panel_controller.js), qui convertit
    # ensuite vers l'unité de base de l'ingrédient retenu.
    INGREDIENT_UNITS = %w[g kg ml cl L càc càs].freeze

    # Ce que le schéma ne peut pas dire : il impose la forme d'un champ, pas ce
    # qu'il faut y mettre. Ces deux règles-là sont donc restées dans le prompt.
    UNIT_RULE = "- unit : laissé à null quand l'ingrédient se compte en pièces (3 oeufs)"
    TIME_RULE = "- total_time_minutes : rempli uniquement si prep_time et cook_time ne sont pas distinguables"

    # Règles communes à l'extraction d'un texte et à celle d'une photo. Elles
    # étaient recopiées dans les deux prompts : une correction apportée d'un seul
    # côté faisait diverger l'import URL de l'import photo, sans que rien ne le
    # signale.
    STRICT_RULES = [ UNIT_RULE, TIME_RULE ].join("\n").freeze

    class << self
      # Recette à extraire du texte d'une page dépourvue de schema.org.
      #
      # @param text [String] texte lisible de la page
      # @return [Hash] { messages:, schema: } pour ClaudeClient
      def text_request(text)
        recipe_request(user_message(<<~PROMPT))
          #{extraction_prompt("Extrait les informations de cette recette", "du texte")}
          Texte de la recette :
          #{text}
        PROMPT
      end

      # Recette à lire sur une photo : l'image précède la consigne, qui commente
      # ce qui vient d'être montré.
      #
      # @param image_base64 [String] image encodée en base64
      # @param media_type [String] type MIME de l'image (ex. "image/jpeg")
      # @return [Hash] { messages:, schema: } pour ClaudeClient
      def photo_request(image_base64, media_type)
        recipe_request(user_message([
          { type: "image", source: { type: "base64", media_type: media_type, data: image_base64 } },
          { type: "text", text: extraction_prompt("Lis cette photo de recette", "de la photo") }
        ]))
      end

      # Ingrédients publiés par schema.org en chaînes brutes ("200 g de farine") :
      # seule leur structuration est demandée, le reste de la recette étant déjà
      # connu. La racine d'un schéma étant toujours un objet, le tableau attendu
      # voyage sous la clé "ingredients" (ExtractorService le déballe).
      #
      # @param raw_ingredients [Array<String>]
      # @return [Hash] { messages:, schema: } pour ClaudeClient
      def ingredients_request(raw_ingredients)
        message = user_message(<<~PROMPT)
          Voici une liste de chaînes d'ingrédients extraites d'une recette. Pour chacune, sépare :
          - "name" : nom de l'ingrédient uniquement (sans quantité ni unité)
          - "quantity" : la quantité, en nombre
          - "unit" : l'unité de cette quantité

          Règles :
          #{UNIT_RULE}

          Ingrédients :
          #{raw_ingredients.map { |ingredient| "- #{ingredient}" }.join("\n")}
        PROMPT

        { messages: [ message ], schema: ingredients_schema }
      end

      private

      # Les deux extractions complètes attendent la même recette : même schéma,
      # une seule écriture.
      def recipe_request(message)
        { messages: [ message ], schema: recipe_schema }
      end

      def user_message(content)
        { role: "user", content: content }
      end

      # Consigne commune aux deux extractions complètes ; seule change la source
      # qu'il ne faut pas trahir.
      def extraction_prompt(instruction, source)
        <<~PROMPT
          #{instruction}.

          Règles :
          #{STRICT_RULES}
          - Ne jamais inventer d'information absente #{source}
        PROMPT
      end

      # Schéma d'une recette complète : ce que l'API fera respecter à la réponse.
      # Les valeurs d'enum sont lues sur Recipe plutôt que recopiées — une valeur
      # hors enum serait de toute façon effacée à la création du brouillon
      # (RecipeImportsController#valid_enum), autant que l'IA ne puisse
      # littéralement pas la produire.
      def recipe_schema
        strict_object(
          name:               { type: "string" },
          description:        nullable("string"),
          default_servings:   nullable("integer"),
          prep_time_minutes:  nullable("integer"),
          cook_time_minutes:  nullable("integer"),
          total_time_minutes: nullable("integer"),
          difficulty:         nullable("string", enum: Recipe.difficulties.keys),
          diet:               { type: "string", enum: Recipe.diets.keys },
          appliance:          nullable("string"),
          instructions:       { type: "string" },
          suggested_tags:     { type: "array", items: { type: "string" } },
          ingredients:        ingredients_array
        )
      end

      def ingredients_schema
        strict_object(ingredients: ingredients_array)
      end

      def ingredients_array
        {
          type:  "array",
          items: strict_object(
            name:     { type: "string" },
            quantity: nullable("number"),
            unit:     nullable("string", enum: INGREDIENT_UNITS)
          )
        }
      end

      # Objet strict, tel que les sorties structurées l'exigent : aucune
      # propriété en plus, et toutes obligatoires.
      def strict_object(**properties)
        {
          type:                 "object",
          properties:           properties,
          required:             properties.keys.map(&:to_s),
          additionalProperties: false
        }
      end

      # Champ facultatif. Toute propriété étant obligatoire, un champ « vide »
      # se déclare en acceptant null en plus de son type.
      def nullable(type, enum: nil)
        value = { type: type }
        value[:enum] = enum if enum

        { anyOf: [ value, { type: "null" } ] }
      end
    end
  end
end
