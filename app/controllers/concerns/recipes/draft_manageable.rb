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
      load_draft_recipes

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

    # Recettes du brouillon dans l'ordre du menu, photo préchargée — alimente le
    # rail du catalogue. Chargement distinct de load_draft_data : la fiche recette
    # n'a besoin que des IDs et n'a pas à payer ces jointures.
    # Toujours requêté (et non lu dans l'association) pour refléter l'état de la
    # base après un toggle.
    def load_draft_recipes
      @draft_recipes = if @draft
        @draft.menu_recipes.by_position
              .includes(recipe: { photo_attachment: :blob })
              .map(&:recipe)
      else
        []
      end
    end
  end
end
