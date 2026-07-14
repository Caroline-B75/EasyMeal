# UC2 — Gestion du menu brouillon depuis le catalogue de recettes
module Recipes
  module DraftManageable
    extend ActiveSupport::Concern

    # POST /recipes/:id/toggle_in_draft
    # UC2 : Toggle ajout/retrait de la recette dans le menu brouillon (Turbo Stream).
    # Si l'utilisateur n'a aucun brouillon, on en démarre un à la volée avec cette
    # recette (« Démarrer un menu ») — hors flux de génération classique.
    def toggle_in_draft
      authorize recipe
      existing_draft = current_draft
      @draft = existing_draft || build_draft_menu
      @draft_created = existing_draft.nil?

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

    # Brouillon vierge aux préférences de l'utilisateur, créé quand aucun menu
    # brouillon n'existe encore. Même convention de nom que Menus::GenerateService.
    def build_draft_menu
      current_user.menus.create!(
        name:           "Menu du #{Date.current.strftime('%d/%m/%Y')}",
        diet:           current_user.default_diet,
        default_people: current_user.default_people,
        status:         :draft
      )
    end

    # Charge le brouillon et les IDs de ses recettes pour l'index (évite N+1)
    def load_draft_data
      return unless current_user

      @draft = current_draft
      @draft_recipe_ids = @draft ? Set.new(@draft.menu_recipes.pluck(:recipe_id)) : Set.new
    end
  end
end
