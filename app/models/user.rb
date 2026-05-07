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
end
