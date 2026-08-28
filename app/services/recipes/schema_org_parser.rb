# frozen_string_literal: true

require "json"

module Recipes
  # Lit le contenu d'une page de recette : d'abord son bloc schema.org
  # (JSON-LD), la source la plus fiable ; à défaut son texte brut, que
  # l'extracteur confiera à l'IA.
  #
  # Toute la connaissance du HTML et du vocabulaire schema.org du projet est ici
  # — et nulle part ailleurs. Chaque méthode est une fonction pure de son
  # argument : rien à porter d'un appel à l'autre, d'où des méthodes de classe
  # plutôt qu'une instance sans état.
  #
  # Un champ JSON-LD vaut indifféremment un scalaire ou un tableau : on le
  # normalise toujours avec Array.wrap, jamais avec Array(), qui éclaterait un
  # Hash en paires clé/valeur.
  #
  # @example
  #   schema = Recipes::SchemaOrgParser.parse_schema_org(html)
  #   schema ? schema["name"] : Recipes::SchemaOrgParser.extract_text(html)
  class SchemaOrgParser
    # Longueur maximale du texte soumis à l'IA quand la page n'a pas de schema.org.
    MAX_TEXT_CHARS = 8_000

    # Balises sans valeur informative pour une recette, retirées avant extraction.
    NOISE_SELECTOR = "script, style, nav, footer, header, aside"

    class << self
      # Premier nœud JSON-LD décrivant une recette dans la page.
      #
      # @param html [String]
      # @return [Hash, nil] le nœud schema.org Recipe, nil si la page n'en porte pas
      def parse_schema_org(html)
        doc = Nokogiri::HTML(html)
        doc.css('script[type="application/ld+json"]').each do |script|
          recipe = json_ld_nodes(JSON.parse(script.content)).find { |node| recipe_type?(node) }
          return recipe if recipe
        rescue JSON::ParserError
          next # bloc malformé : la page peut en porter un autre, exploitable
        end
        nil
      end

      def recipe_type?(data)
        return false unless data.is_a?(Hash)
        # Le type se déclare tantôt par son nom, tantôt par son URL de vocabulaire
        # complète ("https://schema.org/Recipe").
        Array.wrap(data["@type"]).any? { |type| type.to_s.split("/").last == "Recipe" }
      end

      # Les catégories arrivent en vrac, tableau ou liste séparée par des virgules
      # ou des barres obliques : "Plat principal, Tarte".
      def parse_categories(value)
        Array.wrap(value).flat_map { |category| category.to_s.split(/[,\/]/) }.map(&:strip).reject(&:blank?)
      end

      def parse_yield(value)
        return nil if value.blank?
        # Pour les ranges type "4-6 personnes", on prend le dernier chiffre (le plus grand)
        numbers = value.to_s.scan(/\d+/).map(&:to_i)
        numbers.empty? ? nil : numbers.last
      end

      # Convertit une durée ISO 8601 (ex: "PT1H30M") en minutes.
      # La partie horaire suit toujours le "T" : s'y ancrer évite de confondre les
      # minutes avec les mois de la partie calendaire, et couvre les formes
      # complètes du type "P0DT1H30M".
      def parse_iso_duration(value)
        return nil if value.blank?
        match = value.to_s.match(/T(?:(\d+)H)?(?:(\d+)M)?/i)
        return nil if match.nil?
        total = match[1].to_i * 60 + match[2].to_i
        total > 0 ? total : nil
      end

      # Numérote les étapes, qu'elles arrivent en Hash, en String, ou seules hors
      # tableau.
      #
      # La complexité mesurée (9 pour 7) est celle du case/when multi-types : les
      # sites publient leurs instructions dans des formes hétérogènes, et c'est
      # précisément ce que cette méthode absorbe en neuf lignes. Même
      # justification que clean_aliases dans attribute_cleaner.rb.
      # rubocop:disable Metrics/CyclomaticComplexity
      def format_instructions(data)
        return "" if data.blank?
        steps = Array.wrap(data).filter_map do |step|
          case step
          when Hash   then (step["text"] || step["name"])&.strip
          when String then step.strip
          end
        end.reject(&:blank?)
        steps.each_with_index.map { |step, i| "#{i + 1}. #{step}" }.join("\n")
      end
      # rubocop:enable Metrics/CyclomaticComplexity

      # Texte lisible de la page, débarrassé de son habillage : c'est le repli
      # quand aucun schema.org n'est publié.
      def extract_text(html)
        doc = Nokogiri::HTML(html)
        doc.css(NOISE_SELECTOR).remove
        doc.text.gsub(/[ \t]+/, " ").gsub(/\n{3,}/, "\n\n").strip.truncate(MAX_TEXT_CHARS)
      end

      private

      # Aplatit un bloc JSON-LD en la liste de ses nœuds : les sites publient
      # indifféremment un objet nu, un tableau d'objets, ou un objet encapsulant
      # tout son contenu dans @graph.
      def json_ld_nodes(data)
        case data
        when Array then data.flat_map { |node| json_ld_nodes(node) }
        when Hash  then data.key?("@graph") ? json_ld_nodes(data["@graph"]) : [ data ]
        else []
        end
      end
    end
  end
end
