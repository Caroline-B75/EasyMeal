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
  # @example
  #   Groceries::AddManualItemService.call(menu: menu, params: permitted_params)
  #   # => #<struct Result status: :created, item: #<GroceryItem>, message: nil>
  class AddManualItemService
    # Ce que l'ajout a produit, tel que le contrôleur doit y répondre :
    # - :created   → la ligne existe, la liste est rendue à jour ;
    # - :duplicate → l'article y était déjà, on le dit sans rien écrire ;
    # - :invalid   → la saisie ne fait pas une ligne valable (cf. item.errors).
    Result = Struct.new(:status, :item, :message, keyword_init: true)

    # Quantité d'un article ajouté sans en indiquer : « du pain », et non
    # « 250 g de pain ».
    DEFAULT_QUANTITY = 1

    # @param menu [Menu] menu dont on garnit la liste de courses
    # @param params [ActionController::Parameters] name, quantity, unit, category, ingredient_id
    # @return [Result]
    def self.call(menu:, params:)
      new(menu: menu, params: params).call
    end

    def initialize(menu:, params:)
      @menu   = menu
      @params = params
    end

    def call
      return duplicate_result if existing_item

      ingredient ? add_from_catalogue : add_free_item
    end

    private

    attr_reader :menu, :params

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
    # catalogue.
    #
    # L'`ingredient_id` posé par l'autocomplétion d'abord ; à défaut le nom
    # saisi, qui rattrape deux chemins où aucun clic n'a eu lieu — la saisie
    # validée au clavier sans choisir de suggestion, et le formulaire sans
    # JavaScript. « oeufs » retrouve ainsi « Œufs », et « tomate cerise » son
    # ingrédient s'il en est un alias.
    def ingredient
      return @ingredient if defined?(@ingredient)

      @ingredient = Ingredient.find_by(id: params[:ingredient_id]) ||
                    Ingredient.named_like(name).first ||
                    Ingredient.aliased_as(name).first
    end

    # La ligne qui désigne déjà cet article, s'il y en a une : on ne fusionne
    # pas les quantités, on renvoie l'utilisatrice vers la ligne existante,
    # qu'elle peut ajuster d'un clic.
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

    # Article du catalogue : l'ingrédient décrit la ligne, et lui seul sait
    # convertir ce qui a été saisi (une cuillère de farine ne fait des grammes
    # que par sa densité — cf. UnitConversionService).
    def add_from_catalogue
      item = new_item.copy_from_ingredient(ingredient)
      converted = UnitConversionService.convert(quantity: quantity, from_unit: unit, ingredient: ingredient)

      return unconvertible_result(item) if converted.nil?

      item.quantity_base = converted
      save(item)
    end

    # Article hors catalogue : la ligne se décrit elle-même. Son groupe d'unités
    # est celui de l'unité saisie, et la quantité rejoint l'unité de base de ce
    # groupe — « 2 kg » se stocke en 2000 g.
    def add_free_item
      definition = Units.definition(unit)
      item = new_item
      item.name          = name
      item.category      = category
      item.base_unit     = Units::BASE_UNITS[definition[:unit_group]]
      item.quantity_base = (quantity * definition[:factor].to_d).round(3)

      save(item)
    end

    def new_item
      menu.grocery_items.new(source: :manual, checked: false)
    end

    def save(item)
      return Result.new(status: :created, item: item) if item.save

      Result.new(status: :invalid, item: item)
    end

    # Le sélecteur d'unité se restreint aux unités de l'ingrédient dès qu'il est
    # reconnu : n'arrive ici qu'une saisie qui a contourné ce garde-fou.
    def unconvertible_result(item)
      item.errors.add(:base, "« #{item.name} » ne se mesure pas en #{Units.label(unit)}.")
      Result.new(status: :invalid, item: item)
    end
  end
end
