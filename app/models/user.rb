class User < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable

  # === Enums ===

  # Régime alimentaire par défaut — pré-remplit le formulaire de génération de menu
  # Valeurs alignées avec Recipe.diet et Menu.diet
  enum :default_diet, {
    omnivore: 0,
    vegetarien: 1,
    vegan: 2,
    pescetarien: 3
  }, prefix: true

  # === Associations ===

  # Le foyer avec qui le compte partage menus et liste de courses (cf. Household).
  # Toujours présent : un compte naît dans son propre foyer (build_own_household).
  belongs_to :household

  # Les menus du foyer — ceux que le compte voit et modifie, qu'il les ait
  # composés ou non. Lecture seule par ce chemin : un menu se crée dans le foyer
  # (`household.menus.create!`) ; créé par `user.menus`, il n'y serait pas
  # rattaché et échouerait à la validation.
  has_many :menus, through: :household

  # Les articles de courses que ce membre s'est chargé d'acheter (« Je m'en
  # occupe »). Son compte supprimé, ils redeviennent libres.
  has_many :claimed_grocery_items, class_name: "GroceryItem", foreign_key: :claimed_by_id,
                                   inverse_of: :claimed_by, dependent: :nullify

  has_many :favorite_recipes, dependent: :destroy
  has_many :reviews, dependent: :destroy

  # Les imports IA lancés par cette utilisatrice. Détruire le compte n'emporte
  # que les tentatives, jamais les brouillons obtenus : ils appartiennent au
  # catalogue, et le job a déjà transféré la photo de source au brouillon.
  has_many :recipe_imports, dependent: :destroy

  # === Callbacks ===
  before_validation :build_own_household, on: :create
  after_destroy :destroy_household_if_empty

  # === Validations ===
  validates :email, presence: true
  validates :username, presence: true, uniqueness: true
  validates :first_name, presence: true
  validates :last_name, presence: true
  validates :gender, presence: true, inclusion: { in: %w[male female] }

  # Préférences de génération de menu
  validates :default_people, numericality: {
    only_integer: true,
    greater_than_or_equal_to: 1,
    message: "doit être au moins 1"
  }

  # === Méthodes d'instance ===

  # Semaine type mémorisée (UC7) : la répartition des repas par moment, sous
  # forme d'objet-valeur. La colonne jsonb n'est qu'un support de stockage —
  # MealCounts est le seul point d'entrée légitime, en lecture comme en écriture
  # (`user.default_meal_counts = meal_counts.to_h`), et c'est lui qui garantit
  # que d'anciennes valeurs ou une saisie exotique restent inoffensives.
  # @return [MealCounts] répartition vide tant que la semaine n'a pas été décrite
  def preferred_meal_counts
    MealCounts.from_hash(default_meal_counts)
  end

  private

  # Un compte naît seul dans son foyer : il n'y a ainsi jamais de compte sans
  # foyer, et donc aucun cas particulier à traiter ailleurs. Le foyer est
  # enregistré avec le compte (belongs_to enregistre d'abord un parent neuf).
  def build_own_household
    self.household ||= Household.new
  end

  # Un foyer sans membre n'a plus personne pour voir ses menus : il part avec son
  # dernier membre. S'il en reste, le foyer et ses menus leur restent.
  def destroy_household_if_empty
    household.destroy! unless household.members.exists?
  end
end
