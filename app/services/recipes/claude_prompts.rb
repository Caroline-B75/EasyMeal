# frozen_string_literal: true

require "json"

module Recipes
  # Écrit ce qu'on demande à l'IA : les trois conversations de l'import — une
  # recette lue dans du texte, une recette lue sur une photo, une liste
  # d'ingrédients bruts à structurer.
  #
  # Tout le français adressé à Claude vit ici, et nulle part ailleurs :
  # ClaudeClient se charge de l'envoyer sans rien savoir de son contenu. Chaque
  # méthode rend le tableau `messages` attendu par l'API, prêt à être transmis
  # tel quel. Rien à porter d'un appel à l'autre, d'où des méthodes de classe
  # plutôt qu'une instance sans état.
  #
  # @example
  #   Recipes::ClaudeClient.call(Recipes::ClaudePrompts.text_messages(page_text))
  class ClaudePrompts
    # Consigne système, envoyée à chaque appel : elle pose le contrat que
    # ClaudeClient fait ensuite respecter à la réponse — du JSON, et rien d'autre.
    SYSTEM = "Tu es un assistant expert en cuisine. Tu extrais des informations de recettes. " \
             "Tu retournes UNIQUEMENT du JSON valide, sans balises markdown, sans texte avant ou après le JSON."

    # Contraintes de format du JSON attendu, communes à l'extraction d'un texte
    # et à celle d'une photo. Elles étaient recopiées dans les deux prompts :
    # une règle corrigée d'un seul côté faisait diverger l'import URL de
    # l'import photo, sans que rien ne le signale.
    STRICT_RULES = <<~RULES.strip
      - difficulty : "facile", "moyen", "difficile" ou null
      - diet : "omnivore", "vegetarien", "vegan" ou "pescetarien"
      - unit des ingrédients : g, kg, ml, cl, L, càc, càs, ou null (si compté en pièces)
      - total_time_minutes : rempli uniquement si prep_time et cook_time ne sont pas distinguables
    RULES

    class << self
      # Recette à extraire du texte d'une page dépourvue de schema.org.
      #
      # @param text [String] texte lisible de la page
      # @return [Array<Hash>] messages pour l'API
      def text_messages(text)
        [ user_message(<<~PROMPT) ]
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
      # @return [Array<Hash>] messages pour l'API
      def photo_messages(image_base64, media_type)
        [ user_message([
            { type: "image", source: { type: "base64", media_type: media_type, data: image_base64 } },
            { type: "text", text: extraction_prompt("Lis cette photo de recette", "de la photo") }
          ]) ]
      end

      # Ingrédients publiés par schema.org en chaînes brutes ("200 g de farine") :
      # seule leur structuration est demandée, le reste de la recette étant déjà
      # connu.
      #
      # @param raw_ingredients [Array<String>]
      # @return [Array<Hash>] messages pour l'API
      def ingredients_messages(raw_ingredients)
        [ user_message(<<~PROMPT) ]
          Voici une liste de chaînes d'ingrédients extraites d'une recette. Pour chacune, retourne un objet JSON avec :
          - "name" : nom de l'ingrédient uniquement (sans quantité ni unité)
          - "quantity" : nombre décimal (ou null si non précisé)
          - "unit" : parmi g, kg, ml, cl, L, càc, càs, ou null si en pièces

          Retourne UNIQUEMENT un tableau JSON valide, sans texte avant ou après.

          Ingrédients :
          #{raw_ingredients.map { |ingredient| "- #{ingredient}" }.join("\n")}
        PROMPT
      end

      private

      def user_message(content)
        { role: "user", content: content }
      end

      # Consigne commune aux deux extractions complètes : même format de sortie,
      # mêmes règles ; seule change la source qu'il ne faut pas trahir.
      def extraction_prompt(instruction, source)
        <<~PROMPT
          #{instruction} et retourne UNIQUEMENT un JSON valide avec exactement ce format :
          #{json_schema_example}

          Règles strictes :
          #{STRICT_RULES}
          - Ne jamais inventer d'information absente #{source}
        PROMPT
      end

      # Exemple de sortie attendue : montrer le format vaut mieux que le décrire.
      # Les champs sont exactement ceux que la revue de l'import exploite.
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
end
