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
  # Règles de réconciliation (préservent le travail de courses déjà coché) :
  # - quantité inchangée   → rien ne change (coche conservée), previous_quantity_base remis à nil
  # - quantité en baisse    → quantité mise à jour, coche conservée (on a déjà assez acheté)
  # - quantité en hausse + item coché   → décoché + previous_quantity_base = ancienne quantité (badge)
  # - quantité en hausse + item décoché → quantité mise à jour seulement (pas de badge)
  #
  # Les GroceryItems source: :manual ne sont JAMAIS touchés.
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
      # Chargement unique des items générés existants, indexés par ingredient_id (pas de N+1).
      # Les items :manual sont exclus par le scope et donc jamais touchés.
      existing = @menu.grocery_items.generated.index_by(&:ingredient_id)

      aggregated.each do |ingredient_id, data|
        item = existing[ingredient_id]
        item ? update_grocery_item(item, data) : create_grocery_item(data)
      end

      # Ingrédient disparu du menu → supprimer l'item généré correspondant (cas e)
      existing.each do |ingredient_id, item|
        item.destroy! unless aggregated.key?(ingredient_id)
      end
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

    # Met à jour un item généré existant selon les règles de réconciliation (cas a-d).
    # Rafraîchit toujours les attributs dérivés de l'ingrédient (cohérence si l'ingrédient a changé).
    def update_grocery_item(item, data)
      ingredient = data[:ingredient]
      new_qty    = round3(data[:quantity_base])
      old_qty    = round3(item.quantity_base)

      assign_ingredient_attributes(item, ingredient)
      item.quantity_base = new_qty

      if new_qty > old_qty && item.checked?
        # Cas c : hausse sur un item coché → décoche + mémorise l'ancienne quantité (badge)
        item.checked                = false
        item.previous_quantity_base = old_qty
      else
        # Cas a (égalité), b (baisse), d (hausse sur item décoché) : aucun badge
        item.previous_quantity_base = nil
      end

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
      assign_ingredient_attributes(item, data[:ingredient])
      item.save!
    end

    # Copie sur l'item les attributs dérivés de l'ingrédient (dupliqués pour éviter la jointure).
    def assign_ingredient_attributes(item, ingredient)
      item.ingredient = ingredient
      item.name       = ingredient.name
      item.base_unit  = ingredient.base_unit
      item.unit_group = ingredient.unit_group
      item.category   = ingredient.category
    end

    # Arrondit une quantité à 3 décimales en BigDecimal (comparaison exacte, pas de flottant naïf).
    def round3(value)
      value.to_d.round(3)
    end
  end
end
