# frozen_string_literal: true

module Groceries
  # Ajoute un article à la liste de courses depuis le formulaire « Ajouter un
  # article » (UC3).
  #
  # Une seule saisie, deux issues selon que l'article figure ou non au catalogue :
  #
  # - **reconnu** — l'autocomplétion a posé son `ingredient_id`, ou le nom saisi
  #   désigne un ingrédient (ses alias compris, aux accents et à la casse près).
  #   Tout ce qui décrit la ligne — rayon, unité de stockage, comptage à la
  #   pièce — vient alors de l'ingrédient : le rayon et l'unité venus du
  #   formulaire sont ignorés, le navigateur n'a pas à décider dans quel rayon
  #   ranger une tomate.
  # - **inconnu** — la ligne reste libre (`ingredient_id` nul), décrite par le
  #   nom, l'unité et le rayon saisis. Le catalogue est administré : faire ses
  #   courses n'y crée jamais d'ingrédient.
  #
  # Dans les deux cas la quantité est convertie vers l'unité de base de la ligne
  # avant d'être stockée : `quantity_base` ne retient qu'un nombre, toujours relu
  # dans l'unité de base de son groupe (cf. Quantities::HumanizeService).
  #
  # Le même chemin sert aux **courses habituelles** (`usual: true`, cf.
  # Groceries::AddUsualItemsService) : une course habituelle se décrit comme ce
  # qu'on aurait saisi. Seule change l'issue d'un doublon — la quantité
  # s'additionne à la ligne existante, et la ligne retient sa part habituelle.
  #
  # @example
  #   Groceries::AddManualItemService.call(menu: menu, params: permitted_params)
  #   # => #<struct Result status: :created, item: #<GroceryItem>, message: nil>
  class AddManualItemService
    # Ce que l'ajout a produit, tel que le contrôleur doit y répondre :
    # - :created   → la ligne existe, la liste est rendue à jour ;
    # - :merged    → (habituels seulement) la quantité a rejoint une ligne existante ;
    # - :duplicate → l'article y était déjà, on le dit sans rien écrire ;
    # - :invalid   → la saisie ne fait pas une ligne valable (cf. item.errors).
    Result = Struct.new(:status, :item, :message, keyword_init: true)

    # Quantité d'un article ajouté sans en indiquer : « du pain », et non
    # « 250 g de pain ».
    DEFAULT_QUANTITY = 1

    # @param menu [Menu] menu dont on garnit la liste de courses
    # @param params [ActionController::Parameters, Hash] name, quantity, unit, category, ingredient_id
    # @param usual [Boolean] l'article vient des courses habituelles
    # @return [Result]
    def self.call(menu:, params:, usual: false)
      new(menu: menu, params: params, usual: usual).call
    end

    def initialize(menu:, params:, usual: false)
      @menu   = menu
      @params = params
      @usual  = usual
    end

    def call
      return duplicate_result if existing_item && !usual

      item = new_item
      return unconvertible_result(item) unless describe(item)
      return save(item) unless usual

      add_usual(item)
    end

    private

    attr_reader :menu, :params, :usual

    def name
      @name ||= params[:name].to_s.strip
    end

    # L'unité telle qu'elle a été saisie — « kg », « cl », « càs » — et non
    # l'unité de stockage : c'est tout l'objet de la conversion ci-dessous.
    # Ramenée à sa forme canonique, ce qui écarte du même geste une unité
    # absente et une unité forgée : sans unité, un article se compte.
    def unit
      @unit ||= Units.canonical(params[:unit]) || Units::DEFAULT_UNIT
    end

    def quantity
      @quantity ||= params[:quantity].presence&.to_d || DEFAULT_QUANTITY
    end

    # Le rayon saisi, s'il en est un : une valeur inconnue de l'enum lèverait à
    # l'assignation. Un article sans rayon se range sous « divers », ce qui est
    # déjà le sort de celui pour lequel on n'en choisit pas.
    def category
      value = params[:category].to_s
      value if GroceryItem.categories.key?(value)
    end

    # L'ingrédient auquel rattacher la ligne, nil si l'article n'est pas au
    # catalogue : l'`ingredient_id` posé par l'autocomplétion, à défaut le nom
    # saisi (cf. Ingredient.recognize).
    def ingredient
      return @ingredient if defined?(@ingredient)

      @ingredient = Ingredient.recognize(name: name, id: params[:ingredient_id])
    end

    # La ligne qui désigne déjà cet article, s'il y en a une. Un ajout ponctuel
    # ne fusionne pas les quantités : on renvoie l'utilisatrice vers la ligne
    # existante, qu'elle peut ajuster d'un clic. Une course habituelle, elle,
    # s'y additionne (cf. add_usual).
    def existing_item
      return @existing_item if defined?(@existing_item)

      @existing_item = menu.grocery_items.matching_article(name: name, ingredient: ingredient).first
    end

    def duplicate_result
      Result.new(
        status: :duplicate,
        item:   existing_item,
        message: "« #{existing_item.name} » est déjà dans votre liste de courses — " \
                 "vous pouvez ajuster sa quantité directement sur la ligne."
      )
    end

    # Décrit la ligne — nom, rayon, unité de base, quantité convertie — selon
    # que l'article est au catalogue ou non.
    # @return [Numeric, nil] la quantité convertie, nil si elle ne peut pas l'être
    def describe(item)
      ingredient ? describe_from_catalogue(item) : describe_free_item(item)
    end

    # Article du catalogue : l'ingrédient décrit la ligne, et lui seul sait
    # convertir ce qui a été saisi (une cuillère de farine ne fait des grammes
    # que par sa densité — cf. UnitConversionService).
    def describe_from_catalogue(item)
      item.copy_from_ingredient(ingredient)
      item.quantity_base = UnitConversionService.convert(quantity: quantity, from_unit: unit, ingredient: ingredient)
    end

    # Article hors catalogue : la ligne se décrit elle-même. Son groupe d'unités
    # est celui de l'unité saisie, et la quantité rejoint l'unité de base de ce
    # groupe — « 2 kg » se stocke en 2000 g.
    def describe_free_item(item)
      definition = Units.definition(unit)
      item.name          = name
      item.category      = category
      item.base_unit     = Units::BASE_UNITS[definition[:unit_group]]
      item.quantity_base = (quantity * definition[:factor].to_d).round(3)
    end

    # Une course habituelle s'additionne à la ligne qui désigne déjà l'article —
    # le lait du menu et celui de la semaine ne font qu'une ligne. Des unités qui
    # ne s'additionnent pas (des paquets face à des grammes) laissent l'article
    # prendre une ligne à part. Sinon la ligne créée est entièrement habituelle.
    def add_usual(item)
      if existing_item&.base_unit == item.base_unit
        existing_item.add_usual_quantity(item.quantity_base)
        existing_item.save!
        return Result.new(status: :merged, item: existing_item)
      end

      item.usual_quantity_base = item.quantity_base
      save(item)
    end

    # Rattachée par son id et non par `menu.grocery_items.new` : une ligne décrite
    # puis abandonnée — la course habituelle s'est additionnée à une ligne
    # existante, ou la saisie est refusée — ne doit pas rester accrochée à la
    # liste du menu en mémoire.
    def new_item
      GroceryItem.new(menu_id: menu.id, source: :manual, checked: false)
    end

    def save(item)
      return Result.new(status: :created, item: item) if item.save

      Result.new(status: :invalid, item: item)
    end

    def unconvertible_result(item)
      item.errors.add(:base, ingredient.unit_mismatch_message(unit))
      Result.new(status: :invalid, item: item)
    end
  end
end
