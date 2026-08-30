# Représente un ingrédient utilisable dans les recettes
# Chaque ingrédient a un rayon (category), un groupe d'unités (unit_group) et une unité de base
class Ingredient < ApplicationRecord
  # === Concerns ===
  include AttributeCleaner
  # Libellés français des enums (rayon, groupe d'unités) : Ingredient.enum_label,
  # .enum_options pour les sélecteurs — le français vit dans config/locales/fr.yml
  include EnumLabels
  # Ce que le catalogue demande à un ingrédient : le compter (recipes_count,
  # with_recipes_count) et le ranger (sorted_by, SORT_COLUMNS).
  include IngredientCatalog
  # Comment il se compte à l'achat — nom de la pièce, pluriel, contenu d'une
  # pièce : `piece_unit` (PieceUnit) et `counted_by_piece?`.
  include PieceCounting

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
    fruits_surgeles: 10,
    viandes_poissons_surgeles: 11,
    produits_aperitifs_surgeles: 12,
    epicerie_salee: 13,
    epicerie_sucree: 14,
    boissons: 15,
    petit_dejeuner: 16,
    produits_monde: 17,
    hygiene_beaute: 18,
    entretien_maison: 19,
    papeterie_fournitures: 20,
    autre: 21
  }, prefix: true

  # Groupes d'unités de mesure (unité de base associée dans BASE_UNITS)
  enum :unit_group, {
    mass: 0,
    volume: 1,
    count: 2,
    spoon: 3
  }, prefix: true

  # D'où vient la densité de l'ingrédient. Rien d'autre ne distingue les deux
  # valeurs qu'un degré de confiance : une densité `manual` a été écrite ou
  # confirmée par un humain, une densité `ai` n'est qu'une estimation, signalée
  # « à vérifier » partout où elle sert. Nul quand aucune densité n'est connue.
  enum :density_source, { manual: 0, ai: 1 }, prefix: :density_source

  # === Constantes ===

  # Unité de base attendue pour chaque groupe d'unités — celle dans laquelle les
  # quantités sont stockées. Elle est dérivée du vocabulaire des unités (Units),
  # qui sait aussi les convertir et les écrire : ajouter un groupe d'unités ne
  # demande donc de toucher que l'enum ci-dessus et la table de Units.
  #
  # Le nom reste exposé ici parce que c'est à l'ingrédient qu'on le demande : la
  # validation ci-dessous et le formulaire (contrôleur Stimulus
  # `ingredient-form`, alimenté par les partials) lisent cette table.
  BASE_UNITS = Units::BASE_UNITS

  # Plus lourd que ça, ce n'est plus un aliment : le miel plafonne à 1,45 g/ml,
  # le sel fin à 1,2. La borne sert surtout de garde-fou à l'estimation par l'IA.
  MAX_DENSITY = 3

  # « L'un de ses alias vaut :alias_query, aux accents et à la casse près. »
  #
  # Le containment JSONB (`aliases @> '["…"]'`) comparait des chaînes brutes : il
  # exigeait donc l'accent exact, et une recette écrite « puree de tomate » ne
  # retrouvait jamais son alias. Déplier le tableau permet de désaccentuer chaque
  # alias avant comparaison — au prix de l'index GIN, qui ne sert plus ici ; à
  # l'échelle du catalogue (quelques centaines de lignes) c'est indolore.
  #
  # Le CASE n'est pas de la précaution gratuite : la colonne a `{}` pour valeur
  # par défaut, et les ingrédients créés sans alias portent donc un OBJET vide,
  # sur lequel jsonb_array_elements_text lève une erreur.
  ALIAS_MATCH_SQL = <<~SQL.squish
    EXISTS (
      SELECT 1
      FROM jsonb_array_elements_text(
             CASE WHEN jsonb_typeof(ingredients.aliases) = 'array'
                  THEN ingredients.aliases
                  ELSE '[]'::jsonb END
           ) AS candidate
      WHERE unaccent(LOWER(candidate)) = unaccent(LOWER(:alias_query))
    )
  SQL

  # === Associations ===
  has_many :preparations, dependent: :restrict_with_error
  has_many :recipes, through: :preparations
  # Une ligne de courses porte déjà son nom, son rayon et son unité (colonnes
  # recopiées à la génération) : elle survit donc à la disparition de son
  # ingrédient, et c'est bien ce qu'on veut d'une liste imprimée ou en cours de
  # courses. Sans ce nullify, la clé étrangère refuserait le retrait d'un
  # ingrédient sorti du catalogue (cf. la clé `retired` de la seed).
  has_many :grocery_items, dependent: :nullify

  # === Validations ===

  validates :name, presence: { message: "ne peut pas être vide" },
                   uniqueness: {
                     case_sensitive: false,
                     message: "existe déjà"
                   }
  validates :category, presence: { message: "doit être sélectionnée" }
  validates :unit_group, presence: { message: "doit être sélectionné" }
  validates :base_unit, presence: { message: "ne peut pas être vide" }

  # Validation du format de base_unit selon le unit_group
  validate :base_unit_matches_unit_group

  # Les règles de la pièce — poids, volume, nom et pluriel — sont portées par le
  # concern PieceCounting, avec le reste de ce qui la concerne.

  # Densité, facultative elle aussi : elle relie ce qu'une recette mesure (un
  # volume, une cuillère) à ce que le catalogue pèse. Le plafond écarte les
  # valeurs qui ne peuvent pas être des densités alimentaires — le miel, l'un des
  # plus lourds, plafonne à 1,45 g/ml — et met ainsi une borne à ce que l'IA peut
  # écrire en base.
  validates :density_g_per_ml,
            numericality: { greater_than: 0, less_than_or_equal_to: MAX_DENSITY,
                            message: "doit être comprise entre 0 et #{MAX_DENSITY} g/ml" },
            allow_nil: true
  validate :density_only_where_it_converts
  validate :density_source_accompanies_density

  # Validation des season_months (doivent être entre 1 et 12)
  validate :valid_season_months

  # Le groupe d'unités dit comment se lisent toutes les quantités déjà saisies :
  # `preparations.quantity_base` ne stocke qu'un nombre, jamais son unité. Faire
  # passer un ingrédient de la masse au compte relirait donc « 200 g de farine »
  # en « 200 farines » dans chaque recette qui l'emploie, sans conversion ni
  # trace. Tant qu'aucune recette ne l'utilise le changement est sans effet ;
  # après, il est refusé (comme la suppression l'est déjà par l'association).
  validate :unit_group_frozen_once_used, on: :update

  # === Scopes ===

  scope :by_category, ->(category) { where(category: category) }
  scope :by_unit_group, ->(unit_group) { where(unit_group: unit_group) }
  scope :alphabetical, -> { order(:name) }

  # Filtrage par mois de saison (ingrédients disponibles dans un mois donné)
  scope :in_season_for_month, ->(month) {
    return all if month.blank?

    where("season_months @> ARRAY[?]::integer[]", month.to_i)
  }

  # Recherche par nom (fragment) ou par alias (exact), à la casse et aux accents
  # près (cf. ALIAS_MATCH_SQL).
  scope :search, ->(query) {
    return all if query.blank?

    normalized = query.to_s.downcase.strip
    where("unaccent(LOWER(name)) LIKE unaccent(:name_query) OR #{ALIAS_MATCH_SQL}",
          name_query: "%#{sanitize_sql_like(normalized)}%",
          alias_query: normalized)
  }

  # Porte le même nom, aux accents et à la casse près : « epinards » trouve
  # « Épinards », « boeuf haché » trouve « Bœuf haché » (unaccent défait aussi
  # les ligatures).
  scope :named_like, ->(value) { where("unaccent(LOWER(name)) = unaccent(LOWER(:name_query))", name_query: value) }

  # Compte cette écriture parmi ses alias, aux accents et à la casse près.
  scope :aliased_as, ->(value) { where(ALIAS_MATCH_SQL, alias_query: value) }

  # === Méthodes publiques ===

  # Retourne le nom complet avec les alias entre parenthèses
  def display_name
    return name if aliases.blank?

    alias_list = aliases.is_a?(Array) ? aliases.join(", ") : aliases.values.join(", ")
    "#{name} (#{alias_list})"
  end

  # Libellé d'une option du sélecteur d'ingrédient : le nom, puis l'unité dans
  # laquelle cet ingrédient se saisit. Sans elle, on choisissait « Œuf » sans
  # savoir si la quantité attendue était 2 (pièces) ou 100 (grammes) — la même
  # information que le badge d'unité du panneau d'import IA, au même endroit.
  #
  # Le tiret sépare l'unité de la liste d'alias, elle-même entre parenthèses :
  # « Tomate (tomates, tomate ronde) — g ».
  def select_label
    "#{display_name} — #{Units.label(base_unit)}"
  end

  private

  # Valide que base_unit est bien l'unité de base du unit_group (cf. BASE_UNITS)
  def base_unit_matches_unit_group
    return if unit_group.blank? || base_unit.blank?

    expected_unit = BASE_UNITS[unit_group]
    return if base_unit == expected_unit

    errors.add(:base_unit, "doit être #{expected_unit} pour le groupe #{unit_group}")
  end

  # La densité ne relie que la masse et le volume — les cuillères comprises, une
  # cuillère étant un volume. Sur un ingrédient qui se compte à la pièce, elle
  # n'aurait aucun effet à la conversion : autant la refuser que la laisser
  # dormir en base.
  def density_only_where_it_converts
    return if density_g_per_ml.blank? || !unit_group_count?

    errors.add(:density_g_per_ml, "ne s'applique pas aux ingrédients comptés à la pièce")
  end

  # Une densité sans provenance ne pourrait pas se signaler « à vérifier », et une
  # provenance sans densité ne désignerait rien : les deux vont ensemble.
  def density_source_accompanies_density
    return if density_g_per_ml.blank? == density_source.blank?

    if density_g_per_ml.blank?
      errors.add(:density_source, "ne se renseigne qu'avec une densité")
    else
      errors.add(:density_source, "doit dire d'où vient la densité")
    end
  end

  # Fige le groupe d'unités — et l'unité de base qui en découle — dès qu'une
  # recette emploie l'ingrédient (cf. la validation déclarée plus haut).
  def unit_group_frozen_once_used
    return unless unit_group_changed? || base_unit_changed?
    return unless used_in_recipes?

    errors.add(:unit_group,
               "ne peut plus changer : cet ingrédient est utilisé dans #{recipes_usage_label}, " \
               "et les quantités déjà saisies deviendraient fausses")
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
