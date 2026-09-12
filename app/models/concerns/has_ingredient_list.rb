# frozen_string_literal: true

# La liste d'ingrédients d'une recette : l'association, sa saisie imbriquée dans
# le formulaire, et les deux règles qu'elle doit respecter — au moins un
# ingrédient, et une seule ligne par ingrédient.
#
# Seule Recipe l'inclut. Ces règles vivent ensemble parce qu'elles parlent de la
# même chose et se lisent l'une par rapport à l'autre : la première exempte les
# brouillons, la seconde non.
#
# Prérequis du modèle hôte : un prédicat `draft?` (l'exemption ci-dessous s'y
# appuie) et une table de préparations portant un index unique sur
# (recipe_id, ingredient_id).
module HasIngredientList
  extend ActiveSupport::Concern

  # Ce qu'il faut faire d'un ingrédient en double, dit d'un seul endroit : la
  # validation le rappelle en nommant l'ingrédient, le contrôleur sans pouvoir
  # le nommer — il ne rattrape que le refus de l'index, qui ne dit rien de plus.
  DUPLICATE_INGREDIENT_HINT = "garde une seule ligne par ingrédient, en additionnant les quantités"

  included do
    has_many :preparations, dependent: :destroy
    has_many :ingredients, through: :preparations

    # Nested attributes pour créer/modifier les ingrédients via le formulaire
    accepts_nested_attributes_for :preparations,
                                  allow_destroy: true,
                                  reject_if: :all_blank

    # Au moins un ingrédient, sauf brouillon IA : un import se complète
    # progressivement, on ne le bloque pas tant qu'il n'est pas publié.
    validate :must_have_at_least_one_ingredient, unless: :draft?

    # Une ligne par ingrédient, brouillon compris : c'est ce que garantit
    # l'index d'unicité des préparations, et ce qu'il faut donc avoir vérifié
    # avant d'écrire. Preparation porte bien la règle, mais sa validation
    # d'unicité interroge la base : deux lignes neuves visant le même ingrédient
    # y passent toutes les deux, et c'est Postgres qui refuse la seconde en
    # pleine sauvegarde — une erreur 500 là où il fallait un formulaire à
    # corriger. Le cas vient tout droit du panneau d'import, quand la recette
    # d'origine cite un ingrédient à deux endroits (la sauce soja du wok, puis
    # celle de la sauce).
    validate :no_duplicate_ingredient
  end

  # S'assure qu'une ligne d'ingrédient vide attend la saisie dans le formulaire.
  # Réservé aux recettes renseignées à la main : un brouillon reçoit les siens du
  # panneau IA, une ligne vide n'y serait qu'une ligne à supprimer.
  def ensure_preparation_form_ready
    preparations.build if preparations.empty?
  end

  private

  # Les lignes qui existeront après la sauvegarde : ni celles qu'on vient de
  # retirer, ni celles restées sans ingrédient (une ligne vide n'est pas un
  # doublon, c'est une ligne à remplir — et `ingredient_id` a sa propre règle).
  def live_preparations
    preparations.reject { |preparation| preparation.marked_for_destruction? || preparation.ingredient_id.blank? }
  end

  def must_have_at_least_one_ingredient
    return if preparations.reject(&:marked_for_destruction?).any?

    errors.add(:base, "Une recette doit contenir au moins un ingrédient")
  end

  def no_duplicate_ingredient
    duplicates = live_preparations.group_by(&:ingredient_id).values.select { |group| group.size > 1 }
    return if duplicates.empty?

    errors.add(:base, duplicate_ingredient_message(duplicates))
  end

  # Le reproche, nommé quand l'ingrédient peut l'être.
  def duplicate_ingredient_message(duplicates)
    names = duplicates.filter_map { |group| group.first.ingredient&.name }.sort
    return "Un ingrédient apparaît plusieurs fois dans la liste : #{DUPLICATE_INGREDIENT_HINT}." if names.empty?

    verb = names.one? ? "apparaît" : "apparaissent"
    "#{names.to_sentence} #{verb} plusieurs fois dans la liste des ingrédients : #{DUPLICATE_INGREDIENT_HINT}."
  end
end
