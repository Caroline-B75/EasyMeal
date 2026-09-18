# frozen_string_literal: true

# Représente une ligne de la liste de courses d'un menu.
#
# Deux origines possibles :
# - :generated → calculé automatiquement depuis les recettes du menu (via Groceries::BuildForMenuService)
#                Recréé à chaque appel du service (idempotent).
# - :manual    → ajouté manuellement par l'utilisateur.
#                Jamais supprimé lors d'une régénération.
#
# Les quantités sont toujours stockées en unité de base (g, ml, piece, cac)
# et humanisées à l'affichage via Quantities::HumanizeService.
#
# Courses habituelles (UC8, étape 3) : une ligne additionne sa part — menu ou
# ajout ponctuel — et sa part habituelle (`usual_quantity_base`, comprise dans
# `quantity_base`). La part du menu est recalculée à chaque validation, la part
# habituelle est conservée. Une ligne entièrement habituelle est une ligne
# :manual dont la part habituelle vaut le total.
class GroceryItem < ApplicationRecord
  # === Concerns ===
  # Comment cette ligne se compte à l'achat. Les quatre attributs qu'il demande
  # sont recopiés depuis l'ingrédient à la génération, comme le nom et l'unité.
  include PieceCounting
  # « Cet article est-il déjà dans la liste ? » (scope matching_article)
  include ArticleMatching

  # === Associations ===
  belongs_to :menu
  # ingredient_id nullable : null si ligne custom sans ingrédient enregistré en base
  belongs_to :ingredient, optional: true

  # « Je m'en occupe » : le membre du foyer qui achète l'article — celui qui l'a
  # pris, ou celui qui l'a coché. Vide tant que personne ne l'a pris.
  belongs_to :claimed_by, class_name: "User", optional: true, inverse_of: :claimed_grocery_items

  # === Temps réel ===

  # La liste est partagée par le foyer : chaque ligne créée, modifiée ou
  # supprimée demande aux écrans ouverts sur elle de se rafraîchir (Turbo 8,
  # morph — cf. menus/grocery). Turbo regroupe les signaux rapprochés : une
  # revalidation qui touche quarante lignes n'en envoie qu'un, et l'écran à
  # l'origine du changement, déjà à jour, l'ignore.
  broadcasts_refreshes_to ->(item) { item.menu.grocery_stream }

  # === Enums ===

  # Origine de la ligne : générée automatiquement ou ajoutée manuellement
  enum :source, { generated: 0, manual: 1 }, prefix: true

  # Groupe d'unités — dupliqué depuis Ingredient pour éviter la jointure à l'affichage
  enum :unit_group, { mass: 0, volume: 1, count: 2, spoon: 3 }, prefix: true

  # Rayon de supermarché — recopié depuis l'ingrédient, même table (cf. Ingredient::CATEGORIES)
  enum :category, Ingredient::CATEGORIES, prefix: true

  # === Callbacks ===
  before_validation :derive_unit_group_from_base_unit
  before_save :clear_previous_quantity_on_check

  # === Validations ===
  validates :name, presence: { message: "ne peut pas être vide" }

  validates :quantity_base, presence: true,
                            numericality: {
                              greater_than: 0,
                              message: "doit être supérieure à 0"
                            }

  validates :unit_group, presence: { message: "doit être renseigné" }
  validates :base_unit,  presence: { message: "ne peut pas être vide" }

  # === Scopes ===

  # Items générés automatiquement (recalculés lors des régénérations)
  scope :generated, -> { where(source: :generated) }

  # Items ajoutés manuellement (conservés lors des régénérations)
  scope :manual, -> { where(source: :manual) }

  # Items cochés (déjà achetés)
  scope :checked, -> { where(checked: true) }

  # Items non cochés (reste à acheter)
  scope :unchecked, -> { where(checked: false) }

  # Groupement par rayon (catégorie d'ingrédient)
  # La colonne category est dupliquée depuis ingredient pour éviter la jointure
  scope :by_category, ->(cat) { where(category: cat) }

  # Tri : par rayon, non-cochés en premier, puis alphabétique par nom
  scope :sorted, -> { order(:category, :checked, :name) }

  # Lignes prêtes pour l'affichage de la liste : triées, avec le membre qui
  # s'en occupe (son pseudo s'affiche sur la ligne ou sur le rayon).
  scope :for_list, -> { includes(:claimed_by).sorted }

  # Lignes qui doivent une part de leur quantité aux courses habituelles
  scope :with_usual_part, -> { where.not(usual_quantity_base: nil) }

  # Lignes entièrement habituelles : la part habituelle est tout le total
  scope :usual_only, -> { where("usual_quantity_base >= quantity_base") }

  # Ajouts ponctuels : ajoutés à la main, sans rien devoir aux habituels. Ce sont
  # eux qu'on propose de reprendre dans une liste d'habituels encore vide.
  scope :one_off, -> { manual.where(usual_quantity_base: nil) }

  # === Méthodes privées ===
  private

  # Le groupe se déduit de l'unité, et le vocabulaire des unités est seul à
  # savoir laquelle appartient à quel groupe : une table locale y aurait
  # doublonné (et oubliait déjà le centilitre et le décilitre).
  def derive_unit_group_from_base_unit
    self.unit_group = Units.definition(base_unit)&.fetch(:unit_group) if base_unit.present?
  end

  # Efface la trace de l'ancienne quantité (badge « Était X ») dès que l'utilisateur
  # RE-COCHE l'article : cocher = « j'ai bien racheté la nouvelle quantité ».
  # Placé dans le modèle pour couvrir tous les chemins (toggle ET édition de quantité
  # passent par GroceryItemsController#update).
  def clear_previous_quantity_on_check
    self.previous_quantity_base = nil if checked? && will_save_change_to_checked?
  end

  # Formate une quantité en unité de base pour un affichage humain (virgule FR, unités).
  # Partagé par quantity_display et previous_quantity_display (DRY).
  #
  # Ce qui s'achète à la pièce se dit d'abord en pièces — c'est ainsi qu'on
  # remplit un caddie —, la mesure suivant entre parenthèses ou après un
  # « pour » selon qu'elle tombe juste (cf. PieceUnit). Tout le reste se pèse,
  # comme avant.
  #
  # @param value [Numeric, nil] quantité en unité de base
  # @return [String] Ex: "3 kg", "2 pièces (600 g)", "1 brique pour 3 ml", "6"
  def format_quantity(value)
    piece_unit&.sentence_for(value) ||
      Quantities::HumanizeService.call(quantity: value, unit_group: unit_group)[:display]
  end

  public

  # === Méthodes d'instance ===

  # Quantité humanisée pour l'affichage (ne pas stocker, toujours calculé)
  # @return [String] Ex: "3 kg", "1 càs 2 càc", "6"
  def quantity_display
    format_quantity(quantity_base)
  end

  # Ancienne quantité humanisée, pour le badge « Était X — déjà acheté ? »
  # Renseignée uniquement quand une réconciliation a augmenté la quantité d'un item coché.
  # @return [String]
  def previous_quantity_display
    format_quantity(previous_quantity_base)
  end

  # Part habituelle humanisée, pour la note « dont 6 L de tes habituelles »
  # @return [String]
  def usual_quantity_display
    format_quantity(usual_quantity_base)
  end

  # === Courses habituelles ===

  # La ligne ne doit-elle sa quantité qu'aux courses habituelles ? Elle porte
  # alors la marque ↺ seule.
  def usual_only?
    usual_quantity_base.present? && usual_quantity_base >= quantity_base
  end

  # La ligne cumule-t-elle une part habituelle et une autre (menu ou ajout
  # ponctuel) ? Elle dit alors combien vient des habituels.
  def partly_usual?
    usual_quantity_base.present? && usual_quantity_base < quantity_base
  end

  # Donne à la ligne une nouvelle quantité en veillant sur ce qui est déjà
  # acheté : une hausse sur une ligne cochée la décoche et retient l'ancienne
  # quantité (badge « Tu en as peut-être déjà acheté… ») ; toute autre variation
  # efface ce badge.
  #
  # C'est la règle de la réconciliation du menu (Groceries::BuildForMenuService)
  # comme de l'ajout des habituels : dans les deux cas, la quantité grandit sous
  # les yeux de quelqu'un qui a peut-être déjà fait ses courses.
  # @param new_quantity [Numeric] quantité en unité de base
  def reconcile_quantity(new_quantity)
    new_quantity = new_quantity.to_d

    if checked? && new_quantity > quantity_base
      self.checked                = false
      self.previous_quantity_base = quantity_base
    else
      self.previous_quantity_base = nil
    end

    self.quantity_base = new_quantity
  end

  # Ajoute une quantité venue des courses habituelles : le total et la part
  # habituelle grandissent d'autant.
  # @param quantity [Numeric] quantité dans l'unité de base de la ligne
  def add_usual_quantity(quantity)
    self.usual_quantity_base = (usual_quantity_base || 0) + quantity.to_d
    reconcile_quantity(quantity_base + quantity.to_d)
  end

  # Une quantité corrigée à la main porte sur la part habituelle : la part du
  # menu est de toute façon recalculée à chaque validation, et celle d'un ajout
  # ponctuel ne bouge pas. Une correction qui descend sous cette autre part
  # efface la part habituelle.
  #
  # À appeler après l'affectation des attributs, avant l'enregistrement
  # (GroceryItemsController#update, comme assign_buyer). Pas de callback : la
  # réconciliation du menu change aussi la quantité, sans toucher à la part
  # habituelle.
  def shift_quantity_change_to_usual_part
    return if usual_quantity_base.nil? || quantity_base.blank? || !will_save_change_to_quantity_base?

    other_part = quantity_base_in_database - usual_quantity_base
    remaining  = quantity_base - other_part
    self.usual_quantity_base = remaining.positive? ? [ remaining, quantity_base ].min : nil
  end

  # Recopie sur cette ligne ce que son ingrédient sait d'elle : son nom, son
  # rayon, l'unité dans laquelle sa quantité se stocke, et ce qu'il faut pour la
  # compter à l'achat.
  #
  # Ces colonnes sont dupliquées depuis le catalogue — pas de jointure à
  # l'affichage, et la ligne survit au retrait de son ingrédient (cf. le
  # `dependent: :nullify` d'Ingredient). Les écrire ici plutôt que chez chaque
  # appelant évite qu'un chemin en oublie une : la génération depuis les
  # recettes (Groceries::BuildForMenuService) et l'ajout manuel d'un article
  # reconnu au catalogue (Groceries::AddManualItemService) décrivent la même
  # ligne.
  #
  # @param ingredient [Ingredient]
  # @return [GroceryItem] self, pour enchaîner
  def copy_from_ingredient(ingredient)
    self.ingredient = ingredient
    self.name       = ingredient.name
    self.base_unit  = ingredient.base_unit
    self.unit_group = ingredient.unit_group
    self.category   = ingredient.category

    # Comment la ligne se compte à l'achat : nom de la pièce, pluriel, contenu
    # d'une pièce. Recopiés en bloc — un libellé sans son coefficient ne saurait
    # rien afficher (cf. PieceCounting::PIECE_ATTRIBUTES).
    PieceCounting::PIECE_ATTRIBUTES.each do |attribute|
      public_send(:"#{attribute}=", ingredient.public_send(attribute))
    end

    self
  end

  # === « Je m'en occupe » ===

  # Prend l'article pour ce membre du foyer — y compris s'il était pris par un
  # autre : c'est le « Reprendre » de la répartition.
  # @param user [User]
  def claim!(user)
    update!(claimed_by: user)
  end

  # Laisse l'article, seulement s'il était pris par ce membre : on ne rend pas
  # ce qu'un autre a pris.
  # @param user [User]
  def release!(user)
    update!(claimed_by: nil) if claimed_by_id == user.id
  end

  # Cocher, c'est avoir acheté : l'article revient à qui le coche, et c'est ce
  # que lisent les autres membres du foyer. Décocher ne change pas qui s'en occupe.
  # À appeler après l'affectation des attributs, avant l'enregistrement.
  # @param user [User]
  def assign_buyer(user)
    self.claimed_by = user if checked? && will_save_change_to_checked?
  end

  # Ce qu'est l'article pour ce membre du foyer — ce que filtre « Ma part ».
  # @param user [User]
  # @return [String] "mine" (il s'en occupe), "other" (un autre membre), "free" (personne)
  def claim_state_for(user)
    return "free" if claimed_by_id.nil?

    claimed_by_id == user.id ? "mine" : "other"
  end
end
