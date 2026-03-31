# UC2 — Gestion du menu brouillon depuis le catalogue de recettes
module Recipes
  module DraftManageable
    extend ActiveSupport::Concern

    # POST /recipes/:id/add_to_menu
    # UC2 : Ajoute la recette au menu brouillon en cours de l'utilisateur
    def add_to_menu
      draft = current_draft
      return redirect_to(recipe, alert: "Aucun menu brouillon en cours. Générez d'abord un menu.") unless draft

      menu_recipe = draft.menu_recipes.new(recipe: recipe, number_of_people: draft.default_people)
      if menu_recipe.save
        redirect_to draft, notice: "\"#{recipe.name}\" ajoutée au menu."
      else
        redirect_to recipe, alert: menu_recipe.errors.full_messages.to_sentence
      end
    end

    # POST /recipes/:id/toggle_in_draft
    # UC2 : Toggle ajout/retrait de la recette dans le menu brouillon (Turbo Stream)
    def toggle_in_draft
      authorize recipe
      @draft = current_draft
      return respond_no_draft unless @draft

      result = Menus::ToggleDraftRecipeService.call(draft: @draft, recipe: recipe)
      @added = result.added
      @draft.menu_recipes.reload

      respond_success(redirect_path: recipes_path)
    end

    private

    # Menu brouillon de l'utilisateur connecté (ou nil)
    def current_draft
      current_user&.menus&.status_draft&.recent&.first
    end

    # Charge le brouillon et les IDs de ses recettes pour l'index (évite N+1)
    def load_draft_data
      return unless current_user

      @draft = current_draft
      @draft_recipe_ids = @draft ? Set.new(@draft.menu_recipes.pluck(:recipe_id)) : Set.new
    end

    def respond_no_draft
      respond_to do |format|
        format.turbo_stream { render_flash_stream(alert: "Aucun menu brouillon en cours.") }
        format.html { redirect_to recipe, alert: "Aucun menu brouillon en cours." }
      end
    end
  end
end
