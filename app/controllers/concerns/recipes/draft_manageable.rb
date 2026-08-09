# UC2 — Gestion du menu brouillon depuis le catalogue de recettes
module Recipes
  module DraftManageable
    extend ActiveSupport::Concern

    included do
      # Les vues du catalogue s'en servent pour propager le contexte de moment
      # (liens des cartes, boutons d'ajout) — voir context_meal_type.
      helper_method :context_meal_type
    end

    # POST /recipes/:id/toggle_in_draft
    # UC2 : Toggle ajout/retrait de la recette dans le menu brouillon (Turbo Stream).
    # Si l'utilisateur n'a aucun brouillon, on en démarre un à la volée avec cette
    # recette (« Démarrer un menu ») — hors flux de génération classique.
    # Depuis un catalogue filtré par moment (UC7), le repas est créé avec ce
    # moment : la recette arrive dans le brouillon déjà qualifiée.
    def toggle_in_draft
      authorize recipe
      existing_draft = current_draft
      @draft = existing_draft || build_draft_menu
      @draft_created = existing_draft.nil?

      result = Menus::ToggleDraftRecipeService.call(draft: @draft, recipe: recipe,
                                                    meal_type: context_meal_type)
      @added = result.added
      load_draft_recipes

      respond_success(redirect_path: recipes_path)
    end

    private

    # Moment du repas du contexte courant (UC7) : posé dans l'URL par le filtre
    # « Moment du repas » du catalogue, puis transporté de page en page par les
    # liens de recette et les boutons d'ajout. Liste blanche : toute valeur hors
    # vocabulaire vaut absence de contexte.
    def context_meal_type
      params[:meal_type].presence_in(MealTypes::MEAL_TYPES)
    end

    # Menu brouillon de l'utilisateur connecté (ou nil)
    def current_draft
      current_user&.menus&.status_draft&.recent&.first
    end

    # Brouillon vierge aux préférences de l'utilisateur, créé quand aucun menu
    # brouillon n'existe encore.
    def build_draft_menu
      current_user.menus.create!(
        name:           Menu.default_name,
        diet:           current_user.default_diet,
        default_people: current_user.default_people,
        status:         :draft
      )
    end

    # Charge le brouillon et les IDs de ses recettes pour l'index (évite N+1).
    # Dans un contexte de moment (catalogue filtré, UC7), l'état « déjà dans le
    # menu » d'un bouton s'évalue dans ce moment seulement — même règle que le
    # toggle, pour que le bouton fasse toujours ce qu'il affiche.
    def load_draft_data
      return unless current_user

      @draft = current_draft
      @draft_recipe_ids = @draft ? Set.new(draft_meals_in_context.pluck(:recipe_id)) : Set.new
    end

    # Repas du brouillon restreints au moment du contexte, tous sinon
    def draft_meals_in_context
      context_meal_type ? @draft.menu_recipes.for_meal(context_meal_type) : @draft.menu_recipes
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
