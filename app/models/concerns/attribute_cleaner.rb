# Concern pour nettoyer automatiquement les attributs avant sauvegarde
# Utilisé pour standardiser les formats de données (tableaux, chaînes, etc.)
module AttributeCleaner
  extend ActiveSupport::Concern

  included do
    before_validation :clean_attributes
  end

  private

  # Nettoie les attributs qui nécessitent une normalisation
  def clean_attributes
    clean_aliases if respond_to?(:aliases) && aliases_changed?
    clean_season_months if respond_to?(:season_months) && season_months_changed?
  end

  # Convertit aliases en tableau propre
  # Gère les cas : String, Array, Hash
  def clean_aliases
    return if aliases.nil?

    self.aliases = case aliases
                   when String
                     parse_string_to_array(aliases)
                   when Array
                     aliases.map(&:to_s).map(&:strip).reject(&:blank?).uniq
                   when Hash
                     aliases.values.map(&:to_s).map(&:strip).reject(&:blank?).uniq
                   else
                     []
                   end
  end

  # Nettoie season_months : supprime valeurs vides et convertit en entiers
  def clean_season_months
    return if season_months.nil?

    self.season_months = if season_months.is_a?(Array)
                           season_months
                             .reject(&:blank?)
                             .map(&:to_i)
                             .select { |m| m.between?(1, 12) }
                             .uniq
                             .sort
                         else
                           []
                         end
  end

  # Parse une chaîne en tableau (délimitée par virgules)
  def parse_string_to_array(string)
    string.split(',').map(&:strip).reject(&:blank?).uniq
  end
end
