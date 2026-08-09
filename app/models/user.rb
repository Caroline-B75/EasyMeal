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
  has_many :menus, dependent: :destroy
  has_many :favorite_recipes, dependent: :destroy
  has_many :reviews, dependent: :destroy

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
end
