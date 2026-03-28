# Concern pour nettoyer automatiquement les attributs avant sauvegarde
# Utilisé pour standardiser les formats de données (tableaux, chaînes, etc.)
module AttributeCleaner
  extend ActiveSupport::Concern

  # Table de dispatch : chaque type de valeur a sa propre lambda de normalisation.
  # Évite un case/when à forte complexité cyclomatique.
  ALIASES_NORMALIZERS = {
    String => ->(v) { v.split(",").map(&:strip).reject(&:blank?).uniq },
    Array  => ->(v) { v.map(&:to_s).map(&:strip).reject(&:blank?).uniq },
    Hash   => ->(v) { v.values.map(&:to_s).map(&:strip).reject(&:blank?).uniq }
  }.freeze

  included do
    before_validation :clean_attributes
  end

  private

  # Nettoie les attributs qui nécessitent une normalisation
  def clean_attributes
    clean_aliases if respond_to?(:aliases) && aliases_changed?
    clean_season_months if respond_to?(:season_months) && season_months_changed?
  end

  # Convertit aliases en tableau propre via la table de dispatch ALIASES_NORMALIZERS.
  # Retourne un tableau vide pour tout type non reconnu.
  def clean_aliases
    return if aliases.nil?

    normalizer = ALIASES_NORMALIZERS[aliases.class]
    self.aliases = normalizer ? normalizer.call(aliases) : []
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
    string.split(",").map(&:strip).reject(&:blank?).uniq
  end
end
