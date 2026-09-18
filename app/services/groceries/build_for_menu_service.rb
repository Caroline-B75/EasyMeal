# frozen_string_literal: true

module Groceries
  # Génère et réconcilie les GroceryItem(source: :generated) d'un menu.
  #
  # Appelé automatiquement par Menu#activate! (donc aussi à chaque REvalidation
  # après un retour en brouillon — R3.2bis).
  #
  # Algorithme (réconciliation intelligente, plutôt qu'un destroy_all + recréation) :
  # 1. Charger en une requête les items générés existants, indexés par ingredient_id.
  # 2. Agréger les quantités par ingrédient (en unité de base) sur tous les repas.
  # 3. Pour chaque ingrédient agrégé, réconcilier l'item existant OU en créer un neuf.
  # 4. Détruire les items générés dont l'ingrédient a disparu du menu.
  #
  # Règles de réconciliation (préservent le travail de courses déjà coché,
  # cf. GroceryItem#reconcile_quantity) :
  # - quantité inchangée   → rien ne change (coche conservée), previous_quantity_base remis à nil
  # - quantité en baisse    → quantité mise à jour, coche conservée (on a déjà assez acheté)
  # - quantité en hausse + item coché   → décoché + previous_quantity_base = ancienne quantité (badge)
  # - quantité en hausse + item décoché → quantité mise à jour seulement (pas de badge)
  #
  # Courses habituelles (UC8, étape 3) : une ligne additionne la part du menu et
  # sa part habituelle (usual_quantity_base), que le service conserve toujours :
  # - la quantité d'une ligne générée vaut l'agrégat du menu + sa part habituelle ;
  # - une ligne générée que le menu ne demande plus, mais qui a une part
  #   habituelle, redevient une ligne :manual réduite à cette part ;
  # - une ligne :manual entièrement habituelle dont le menu demande désormais
  #   l'ingrédient rejoint le menu, plutôt que de voir naître une seconde ligne.
  #
  # Hors ce dernier cas, les GroceryItems source: :manual ne sont JAMAIS touchés.
  # Le service est idempotent : deux appels sans changement de menu ne modifient rien.
  #
  # @example
  #   Groceries::BuildForMenuService.call(menu: menu)
  class BuildForMenuService
    # @param menu [Menu]
    # @return [void]
    def self.call(menu:)
      new(menu: menu).call
    end

    def initialize(menu:)
      @menu = menu
    end

    def call
      ActiveRecord::Base.transaction do
        reconcile(aggregate_ingredients)
      end
    end

    private

    # Réconcilie les items générés existants avec l'agrégation courante du menu.
    # @param aggregated [Hash<Integer, Hash>] { ingredient_id => { ingredient:, quantity_base: } }
    def reconcile(aggregated)
      # Chargement unique des items générés existants, groupés par ingredient_id
      # (pas de N+1). Les items :manual sont exclus par le scope et donc jamais
      # touchés.
      #
      # Groupés, et non indexés : la suppression d'un ingrédient du catalogue met
      # `ingredient_id` à NULL sur ses lignes de courses (dependent: :nullify).
      # Plusieurs orphelines partagent alors la clé nil, dont un index_by n'aurait
      # gardé qu'une — les autres auraient échappé au nettoyage pour toujours.
      existing = @menu.grocery_items.generated.group_by(&:ingredient_id)
      adoptable = usual_lines_by_ingredient

      aggregated.each do |ingredient_id, data|
        # `shift` retire l'item du groupe : ce qui reste après cette boucle
        # n'appartient plus au menu et se retire d'un seul geste ci-dessous.
        item = existing[ingredient_id]&.shift || adoptable[ingredient_id]
        item ? update_grocery_item(item, data) : create_grocery_item(data)
      end

      # Reste ici tout ce que le menu ne demande plus : ingrédient retiré d'une
      # recette (cas e), et lignes orphelines d'ingrédients supprimés du catalogue.
      existing.values.flatten.each { |item| retire(item) }
    end

    # Les lignes ajoutées par les seuls habituels, par ingrédient : si le menu
    # demande désormais cet ingrédient, c'est l'une d'elles qu'il reprend. Une
    # ligne qui compte un ajout ponctuel n'est jamais adoptée — elle cohabite
    # avec la ligne du menu, comme tout ajout manuel.
    # @return [Hash<Integer, GroceryItem>]
    def usual_lines_by_ingredient
      @menu.grocery_items.manual.usual_only.where.not(ingredient_id: nil).index_by(&:ingredient_id)
    end

    # Une ligne que le menu ne demande plus disparaît… sauf sa part habituelle,
    # qui reste sur la liste en ligne :manual.
    def retire(item)
      return item.destroy! if item.usual_quantity_base.nil?

      item.source = :manual
      item.reconcile_quantity(item.usual_quantity_base)
      item.save!
    end

    # Agrège les quantités par ingrédient sur tous les repas du menu.
    # @return [Hash<Integer, Hash>] { ingredient_id => { ingredient:, quantity_base: } }
    def aggregate_ingredients
      aggregated = Hash.new { |h, k| h[k] = { ingredient: nil, quantity_base: 0.0 } }

      # Préchargement pour éviter N+1 queries
      @menu.menu_recipes
           .includes(recipe: { preparations: :ingredient })
           .each do |menu_recipe|
        accumulate_menu_recipe(menu_recipe, aggregated)
      end

      aggregated
    end

    # Ajoute la contribution d'un repas à l'agrégation.
    def accumulate_menu_recipe(menu_recipe, aggregated)
      factor = menu_recipe.scale_factor

      menu_recipe.recipe.preparations.each do |preparation|
        ingredient = preparation.ingredient
        aggregated[ingredient.id][:ingredient]    = ingredient
        aggregated[ingredient.id][:quantity_base] += (preparation.quantity_base * factor)
      end
    end

    # Met à jour un item existant — généré, ou adopté parmi les lignes
    # habituelles — selon les règles de réconciliation (cas a-d). Sa quantité
    # est celle du menu plus sa part habituelle.
    # Rafraîchit toujours les attributs dérivés de l'ingrédient (cohérence si l'ingrédient a changé).
    def update_grocery_item(item, data)
      item.source = :generated
      item.copy_from_ingredient(data[:ingredient])
      item.reconcile_quantity(round3(data[:quantity_base]) + (item.usual_quantity_base || 0))

      # Idempotence : n'écrit que si quelque chose a réellement changé
      item.save! if item.changed?
    end

    # Crée un GroceryItem persisté à partir des données agrégées d'un ingrédient (cas f).
    def create_grocery_item(data)
      item = @menu.grocery_items.new(
        quantity_base: round3(data[:quantity_base]),
        source:        :generated,
        checked:       false
      )
      item.copy_from_ingredient(data[:ingredient])
      item.save!
    end

    # Arrondit une quantité à 3 décimales en BigDecimal (comparaison exacte, pas de flottant naïf).
    def round3(value)
      value.to_d.round(3)
    end
  end
end
