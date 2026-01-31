# frozen_string_literal: true

module Quantities
  # Service pour convertir une quantité brute en affichage lisible
  # 
  # Règles d'humanisation par groupe d'unités :
  # - mass (g)    : >= 1000g → kg (ex: 1500g → "1,5 kg")
  # - volume (ml) : >= 1000ml → L (ex: 2000ml → "2 L")
  # - spoon (cac) : conversion en càs si divisible par 3, sinon mixé
  #                 très petites quantités → pincées (0,25 cac = 1 pincée)
  # - count       : entier si possible, sinon 1 décimale max
  #
  # @example
  #   Quantities::HumanizeService.call(quantity: 1500, unit_group: :mass)
  #   # => { value: "1,5", unit: "kg", display: "1,5 kg" }
  #
  class HumanizeService
    # Seuils de conversion
    MASS_THRESHOLD = 1000     # g → kg
    VOLUME_THRESHOLD = 1000   # ml → L
    CAC_PER_CAS = 3           # 3 càc = 1 càs
    CAC_PER_PINCEE = 0.25     # 1 pincée = 0,25 càc

    # Point d'entrée principal (class method)
    def self.call(quantity:, unit_group:)
      new(quantity: quantity, unit_group: unit_group).call
    end

    def initialize(quantity:, unit_group:)
      @quantity = quantity.to_f
      @unit_group = unit_group.to_s.to_sym
    end

    # Retourne un hash avec la valeur formatée, l'unité et l'affichage complet
    def call
      result = case @unit_group
               when :mass then humanize_mass
               when :volume then humanize_volume
               when :spoon then humanize_spoon
               when :count then humanize_count
               else fallback_display
               end

      build_result(result[:value], result[:unit])
    end

    private

    # === MASSE (g → kg) ===
    def humanize_mass
      if @quantity >= MASS_THRESHOLD
        { value: format_number(@quantity / 1000.0), unit: "kg" }
      else
        { value: format_number(@quantity), unit: "g" }
      end
    end

    # === VOLUME (ml → L) ===
    def humanize_volume
      if @quantity >= VOLUME_THRESHOLD
        { value: format_number(@quantity / 1000.0), unit: "L" }
      else
        { value: format_number(@quantity), unit: "ml" }
      end
    end

    # === CUILLÈRES (càc → càs / pincées) ===
    # Logique complexe pour un affichage naturel
    def humanize_spoon
      return humanize_pincees if @quantity < 1 && @quantity > 0

      cas_count = (@quantity / CAC_PER_CAS).floor
      cac_remainder = @quantity % CAC_PER_CAS

      if cac_remainder.zero?
        # Divisible exactement par 3 → afficher en càs
        { value: format_integer(cas_count), unit: "càs" }
      elsif cas_count.zero?
        # Moins de 3 càc → afficher en càc
        { value: format_number(cac_remainder), unit: "càc" }
      else
        # Mix càs + càc (ex: "1 càs 2 càc")
        { value: "#{format_integer(cas_count)} càs #{format_number(cac_remainder)}", unit: "càc" }
      end
    end

    # Très petites quantités en pincées
    def humanize_pincees
      pincees = (@quantity / CAC_PER_PINCEE).round
      pincees = 1 if pincees.zero? && @quantity > 0

      unit = pincees > 1 ? "pincées" : "pincée"
      { value: format_integer(pincees), unit: unit }
    end

    # === NOMBRE (pièces) ===
    def humanize_count
      # Arrondir à l'entier si très proche, sinon 1 décimale
      if (@quantity - @quantity.round).abs < 0.1
        { value: format_integer(@quantity.round), unit: "" }
      else
        { value: format_number(@quantity, max_decimals: 1), unit: "" }
      end
    end

    # Fallback pour les groupes inconnus
    def fallback_display
      { value: format_number(@quantity), unit: "" }
    end

    # === FORMATAGE ===

    # Formate un nombre avec virgule française, sans zéros inutiles
    # @param number [Numeric] le nombre à formater
    # @param max_decimals [Integer] nombre max de décimales (défaut: 2)
    def format_number(number, max_decimals: 2)
      return "0" if number.zero?

      # Arrondir selon le nombre de décimales demandé
      rounded = number.round(max_decimals)

      # Convertir en string et remplacer le point par une virgule
      # Supprimer les zéros inutiles après la virgule
      formatted = rounded.to_s
                         .sub(/\.0+$/, '')           # Supprime ".0" ou ".00"
                         .sub(/(\.\d*?)0+$/, '\1')   # Supprime les zéros trailing
                         .sub('.', ',')              # Point → virgule (FR)

      formatted
    end

    # Formate un entier (sans décimales)
    def format_integer(number)
      number.to_i.to_s
    end

    # Construit le résultat final
    def build_result(value, unit)
      display = unit.present? ? "#{value} #{unit}".strip : value.to_s
      
      {
        value: value,
        unit: unit,
        display: display
      }
    end
  end
end
