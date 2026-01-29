# Représente un ingrédient utilisable dans les recettes
# Chaque ingrédient a un rayon (category), un groupe d'unités (unit_group) et une unité de base
class Ingredient < ApplicationRecord
  # === Enums ===
  
  # Rayons de supermarché (catégories d'ingrédients)
  enum :category, {
    fruits_legumes: 0,
    boucherie_viande: 1,
    charcuterie_traiteur: 2,
    poissonnerie: 3,
    fromagerie_coupe: 4,
    boulangerie_patisserie: 5,
    produits_laitiers: 6,
    produits_frais_libre_service: 7,
    glaces_desserts_glaces: 8,
    legumes_surgeles: 9,
    viandes_poissons_surgeles: 10,
    produits_aperitifs_surgeles: 11,
    epicerie_salee: 12,
    epicerie_sucree: 13,
    boissons: 14,
    petit_dejeuner: 15,
    produits_monde: 16,
    hygiene_beaute: 17,
    entretien_maison: 18,
    papeterie_fournitures: 19,
    autre: 20
  }, prefix: true

  # Groupes d'unités de mesure
  enum :unit_group, {
    mass: 0,      # masse (base: g)
    volume: 1,    # volume (base: ml)
    count: 2,     # nombre (base: piece)
    spoon: 3      # cuillères (base: cac)
  }, prefix: true

  # Traductions françaises des catégories
  def self.human_attribute_name(attr, options = {})
    if attr.to_s.start_with?('category.')
      category_key = attr.to_s.sub('category.', '')
      {
        'fruits_legumes' => 'Fruits et légumes',
        'boucherie_viande' => 'Boucherie / Viande',
        'charcuterie_traiteur' => 'Charcuterie / Traiteur',
        'poissonnerie' => 'Poissonnerie',
        'fromagerie_coupe' => 'Fromagerie / Coupe',
        'boulangerie_patisserie' => 'Boulangerie / Pâtisserie',
        'produits_laitiers' => 'Produits laitiers',
        'produits_frais_libre_service' => 'Produits frais en libre-service',
        'glaces_desserts_glaces' => 'Glaces et desserts glacés',
        'legumes_surgeles' => 'Légumes surgelés',
        'viandes_poissons_surgeles' => 'Viandes et poissons surgelés',
        'produits_aperitifs_surgeles' => 'Produits apéritifs surgelés',
        'epicerie_salee' => 'Épicerie salée',
        'epicerie_sucree' => 'Épicerie sucrée',
        'boissons' => 'Boissons',
        'petit_dejeuner' => 'Petit-déjeuner',
        'produits_monde' => 'Produits du monde',
        'hygiene_beaute' => 'Hygiène et beauté',
        'entretien_maison' => 'Entretien de la maison',
        'papeterie_fournitures' => 'Papeterie et fournitures',
        'autre' => 'Autre'
      }[category_key] || category_key.humanize
    elsif attr.to_s.start_with?('unit_group.')
      unit_key = attr.to_s.sub('unit_group.', '')
      {
        'mass' => 'Masse (g, kg)',
        'volume' => 'Volume (ml, L)',
        'count' => 'Nombre (pièces)',
        'spoon' => 'Cuillères (càc, càs)'
      }[unit_key] || unit_key.humanize
    else
      super
    end
  end

  # === Validations ===
  
  validates :name, presence: true, 
                   uniqueness: { 
                     case_sensitive: false,
                     message: "existe déjà dans la base de données. Utilisez la recherche pour le retrouver."
                   }
  validates :category, presence: true
  validates :unit_group, presence: true
  validates :base_unit, presence: true
  
  # Validation du format de base_unit selon le unit_group
  validate :base_unit_matches_unit_group
  
  # Validation des season_months (doivent être entre 1 et 12)
  validate :valid_season_months

  # === Scopes ===
  
  scope :by_category, ->(category) { where(category: category) }
  scope :by_unit_group, ->(unit_group) { where(unit_group: unit_group) }
  scope :alphabetical, -> { order(:name) }
  
  # Filtrage par mois de saison (ingrédients disponibles dans un mois donné)
  scope :in_season_for_month, ->(month) {
    return all if month.blank?
    
    where("season_months @> ARRAY[?]::integer[]", month.to_i)
  }
  
  # Recherche par nom ou alias
  scope :search, ->(query) {
    return all if query.blank?
    
    sanitized_query = sanitize_sql_like(query.downcase)
    where("LOWER(name) LIKE :query OR aliases @> :json_query", 
          query: "%#{sanitized_query}%",
          json_query: ["\"#{sanitized_query}\""].to_json)
  }

  # === Méthodes publiques ===
  
  # Retourne le nom complet avec les alias entre parenthèses
  def display_name
    return name if aliases.blank?
    
    alias_list = aliases.is_a?(Array) ? aliases.join(', ') : aliases.values.join(', ')
    "#{name} (#{alias_list})"
  end
  
  # Retourne l'unité de base en fonction du unit_group
  def default_base_unit
    case unit_group
    when 'mass' then 'g'
    when 'volume' then 'ml'
    when 'count' then 'piece'
    when 'spoon' then 'cac'
    end
  end

  private

  # Valide que base_unit correspond bien au unit_group
  def base_unit_matches_unit_group
    valid_units = {
      'mass' => ['g'],
      'volume' => ['ml'],
      'count' => ['piece'],
      'spoon' => ['cac']
    }
    
    return if unit_group.blank? || base_unit.blank?
    
    unless valid_units[unit_group]&.include?(base_unit)
      errors.add(:base_unit, "doit être #{valid_units[unit_group]&.join(' ou ')} pour le groupe #{unit_group}")
    end
  end
  
  # Valide que tous les season_months sont entre 1 et 12
  def valid_season_months
    return if season_months.blank?
    
    invalid_months = season_months.reject { |m| m.between?(1, 12) }
    if invalid_months.any?
      errors.add(:season_months, "contient des mois invalides: #{invalid_months.join(', ')}")
    end
  end
end
