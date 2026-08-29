# frozen_string_literal: true

module Recipes
  # Écrit ce qu'on demande à l'IA : les trois conversations de l'import — une
  # recette lue dans du texte, une recette lue sur une photo, une recette déjà
  # décrite par schema.org dont il reste à structurer les ingrédients.
  #
  # Chaque méthode rend une demande complète : les `messages` à envoyer et le
  # `schema` JSON auquel la réponse devra se conformer. Les deux voyagent
  # ensemble parce qu'ils se répondent — le prompt dit quoi lire et quoi juger,
  # le schéma dit sous quelle forme le rendre. Et comme l'API fait respecter le
  # second (sorties structurées), le premier n'a plus à mendier du JSON ni à
  # décrire le format attendu : il ne parle que de cuisine.
  #
  # Aucun vocabulaire fermé ne se recopie ici : les moments viennent de
  # MealTypes, les régimes, difficultés et budgets des enums de Recipe, les tags
  # des noms en base, et les unités de Units. L'IA ne peut donc littéralement
  # pas proposer une valeur que le formulaire de validation refuserait.
  #
  # Tout le français adressé à Claude à propos d'une recette vit ici, et nulle
  # part ailleurs : ClaudeClient se charge de l'envoyer sans rien savoir de son
  # contenu. Rien à porter d'un appel à l'autre, d'où des méthodes de classe
  # plutôt qu'une instance sans état.
  #
  # La grammaire des schémas de sortie, elle, n'a rien de propre aux recettes :
  # elle vit dans JsonSchema, partagée avec les autres demandes du projet.
  #
  # @example
  #   Recipes::ClaudeClient.call(Recipes::ClaudePrompts.text_request(page_text))
  class ClaudePrompts
    # Consigne système, envoyée à chaque appel.
    SYSTEM = "Tu es un assistant expert en cuisine. Tu extrais des informations de recettes " \
             "et tu les classes pour un catalogue familial."

    # Au-delà, les tags cessent de trier : une recette qui porte tout le
    # catalogue ne se distingue plus de ses voisines dans les filtres.
    MAX_TAGS = 4

    # Ce que le schéma ne peut pas dire : il impose la forme d'un champ, pas ce
    # qu'il faut y mettre. Ces deux règles-là sont donc restées dans le prompt.
    #
    # Les cuillères se disent en toutes lettres jusque dans le schéma
    # (Units::AI_UNITS) et la règle nomme une à une les abréviations qui y
    # mènent : « càc » et « càs » ne diffèrent que d'une lettre, et le modèle
    # les confondait — « 3 c. à s. d'huile d'olive » ressortait en « 3 càc ».
    # Une quantité divisée par trois ne se voit pas à la relecture.
    UNIT_RULE = <<~RULE.strip
      - unit : laissé à null quand l'ingrédient se compte en pièces (3 oeufs)
      - unit : ne jamais confondre les deux cuillères, elles valent trois fois
        moins l'une que l'autre. « c. à s. », « c à s », « cs », « cuil. à soupe »,
        « cuillère(s) à soupe » → cuillere_a_soupe. « c. à c. », « c à c », « cc »,
        « cuil. à café », « cuillère(s) à café », « cuillère(s) à thé » → cuillere_a_cafe
    RULE
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
        tags = catalog_tags

        recipe_request(user_message(<<~PROMPT), tags)
          #{extraction_prompt("Extrait les informations de cette recette", "du texte", tags)}
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
        tags = catalog_tags

        recipe_request(user_message([
          { type: "image", source: { type: "base64", media_type: media_type, data: image_base64 } },
          { type: "text", text: extraction_prompt("Lis cette photo de recette", "de la photo", tags) }
        ]), tags)
      end

      # Recette dont le site publie déjà les faits (schema.org) : restent les
      # deux choses qu'il ne dit pas, et un seul appel les demande toutes les
      # deux — des ingrédients structurés, et un classement.
      #
      # Le tableau d'ingrédients attendu voyage sous une clé, la racine d'un
      # schéma étant toujours un objet (ExtractorService le déballe).
      #
      # @param name [String, nil] nom de la recette
      # @param description [String, nil]
      # @param categories [Array<String>] catégories annoncées par le site
      # @param instructions [String, nil] étapes déjà mises en forme
      # @param ingredients [Array<String>] ingrédients en texte libre
      # @return [Hash] { messages:, schema: } pour ClaudeClient
      def schema_org_request(name:, description:, categories:, instructions:, ingredients:)
        tags    = catalog_tags
        message = user_message(<<~PROMPT)
          Voici une recette publiée par un site, avec sa liste d'ingrédients en texte libre.
          Deux choses à faire.

          1. Structurer chaque ingrédient :
          - "name" : nom de l'ingrédient uniquement (sans quantité ni unité)
          - "quantity" : la quantité, en nombre
          - "unit" : l'unité de cette quantité
          #{UNIT_RULE}

          2. Classer la recette :
          #{classification_rules(tags)}
          #{recipe_summary(name, description, categories, instructions)}

          #{ingredients_section(ingredients)}
        PROMPT

        { messages: [ message ], schema: schema_org_schema(tags) }
      end

      private

      # Les deux extractions complètes attendent la même recette : même schéma,
      # une seule écriture.
      def recipe_request(message, tags)
        { messages: [ message ], schema: recipe_schema(tags) }
      end

      def user_message(content)
        { role: "user", content: content }
      end

      # Consigne commune aux deux extractions complètes ; seule change la source
      # qu'il ne faut pas trahir. Extraire et classer sont deux gestes opposés,
      # d'où deux blocs de règles bien séparés : le premier interdit d'inventer,
      # le second demande justement de trancher.
      def extraction_prompt(instruction, source, tags)
        <<~PROMPT
          #{instruction}.

          Règles d'extraction — ne jamais inventer d'information absente #{source} :
          #{STRICT_RULES}

          Règles de classement — ici il faut juger, même quand la source ne le dit pas :
          #{classification_rules(tags)}
        PROMPT
      end

      # Comment classer une recette. Les valeurs possibles ne sont pas répétées
      # ici : le schéma les impose déjà, ce bloc dit seulement comment choisir.
      def classification_rules(tags)
        rules = <<~RULES
          - diet : le régime le PLUS restrictif qui s'applique réellement — une recette
            sans viande ni poisson est végétarienne, pas omnivore ; sans aucun produit
            animal, elle est végane
          - meal_types : tous les moments qui conviennent, un plat salé classique allant
            au déjeuner ET au dîner ; les autres moments seulement quand c'est manifeste.
            Moments possibles : #{meal_types_vocabulary}
          - price : le budget de la recette, d'après le coût habituel de ses ingrédients
          - difficulty : d'après la technique demandée et le nombre d'étapes
        RULES

        tags.any? ? rules + tags_rule(tags) : rules
      end

      # Les moments sont des clés anglaises : sans leur libellé, « apero » et
      # « snack » se confondent.
      def meal_types_vocabulary
        MealTypes::MEAL_TYPES.map { |type| "#{type} (#{MealTypes.label(type)})" }.join(", ")
      end

      # Catalogue de tags injecté tel quel : l'IA choisit dedans, et le schéma
      # l'empêche d'en inventer. Les types guident le choix (une cuisine du
      # monde et une saison ne se cochent pas pour les mêmes raisons).
      def tags_rule(tags)
        catalog = Tag.grouped_by_type(tags).map do |_key, type_label, group|
          "  #{type_label} : #{group.map(&:name).join(', ')}"
        end

        <<~RULES
          - tags : de 0 à #{MAX_TAGS} tags, uniquement ceux qui s'appliquent vraiment,
            à choisir dans ce catalogue :
          #{catalog.join("\n")}
        RULES
      end

      # Ce que le site dit déjà de la recette : de quoi la classer sans avoir à
      # relire la page. Les champs vides sont tus plutôt qu'annoncés vides.
      def recipe_summary(name, description, categories, instructions)
        {
          "Recette"                          => name,
          "Description"                      => description,
          "Catégories annoncées par le site" => Array(categories).join(", "),
          "Étapes"                           => instructions
        }.filter_map { |label, value| "#{label} : #{value}" if value.present? }.join("\n")
      end

      def ingredients_section(ingredients)
        return "Le site ne liste aucun ingrédient : rends un tableau ingredients vide." if ingredients.blank?

        "Ingrédients :\n#{ingredients.map { |ingredient| "- #{ingredient}" }.join("\n")}"
      end

      # Tags du catalogue, chargés une fois par demande : ils servent deux fois,
      # dans le prompt et dans le schéma.
      def catalog_tags
        Tag.alphabetical.to_a
      end

      # Schéma d'une recette complète : ce que l'API fera respecter à la réponse.
      def recipe_schema(tags)
        JsonSchema.strict_object(
          name:               { type: "string" },
          description:        JsonSchema.nullable("string"),
          default_servings:   JsonSchema.nullable("integer"),
          prep_time_minutes:  JsonSchema.nullable("integer"),
          cook_time_minutes:  JsonSchema.nullable("integer"),
          total_time_minutes: JsonSchema.nullable("integer"),
          appliance:          JsonSchema.nullable("string"),
          instructions:       { type: "string" },
          ingredients:        ingredients_array,
          **classification_properties(tags)
        )
      end

      # Chemin schema.org : les faits sont déjà connus, seuls les ingrédients et
      # le classement sont demandés.
      def schema_org_schema(tags)
        JsonSchema.strict_object(ingredients: ingredients_array, **classification_properties(tags))
      end

      # Champs de classement, communs aux trois demandes. Les valeurs sont lues
      # sur les modèles plutôt que recopiées : une valeur hors enum serait de
      # toute façon effacée à la création du brouillon
      # (RecipeImportsController#valid_enum), autant que l'IA ne puisse
      # littéralement pas la produire.
      def classification_properties(tags)
        properties = {
          difficulty: JsonSchema.nullable("string", enum: Recipe.difficulties.keys),
          diet:       { type: "string", enum: Recipe.diets.keys },
          price:      JsonSchema.nullable("string", enum: Recipe.prices.keys),
          meal_types: { type: "array", items: { type: "string", enum: MealTypes::MEAL_TYPES } }
        }
        # Catalogue vide (nouvelle installation) : pas d'enum possible, donc pas
        # de champ — plutôt qu'un schéma qui n'autoriserait aucune valeur.
        properties[:tags] = { type: "array", items: { type: "string", enum: tags.map(&:name) } } if tags.any?
        properties
      end

      def ingredients_array
        {
          type:  "array",
          items: JsonSchema.strict_object(
            name:     { type: "string" },
            quantity: JsonSchema.nullable("number"),
            unit:     JsonSchema.nullable("string", enum: Units::AI_UNITS)
          )
        }
      end
    end
  end
end
