# UC2 — Personnalisation : ajout, remplacement et régénération de repas
module Menus
  module Customizable
    extend ActiveSupport::Concern

    # POST /menus/:id/add_random_meal
    # Ajoute un repas aléatoire en tenant compte du régime et de la saison
    def add_random_meal
      @menu_recipe = Menus::AddRandomMealService.call(menu: @menu)
      respond_to do |format|
        format.turbo_stream
        format.html { redirect_to @menu, status: :see_other }
      end
    rescue Menus::NoCandidatesError => error
      respond_with_no_candidates(error)
    end

    # POST /menus/:id/replace_meal
    # Remplace un repas par un autre (params: menu_recipe_id)
    def replace_meal
      @old_menu_recipe = @menu.menu_recipes.find(params[:menu_recipe_id])
      @menu_recipe = Menus::ReplaceMealService.call(menu: @menu, menu_recipe: @old_menu_recipe)
      respond_to do |format|
        format.turbo_stream
        format.html { redirect_to @menu }
      end
    rescue ActiveRecord::RecordNotFound
      redirect_to @menu, alert: "Ce repas est introuvable.", status: :see_other
    rescue Menus::NoCandidatesError => error
      respond_with_no_candidates(error)
    end

    # POST /menus/:id/regenerate
    # Re-génère le menu brouillon avec de nouveaux paramètres
    def regenerate
      @menu.menu_recipes.destroy_all
      @menu.update!(menu_params.except(:number_of_meals))

      Menus::RegenerateService.call(
        menu:            @menu,
        number_of_meals: menu_params[:number_of_meals].to_i
      )

      redirect_to @menu, notice: "Menu re-généré avec les nouveaux paramètres !", status: :see_other
    rescue Menus::NoCandidatesError => error
      flash.now[:alert] = error.message
      render :edit, status: :unprocessable_entity
    end

    private

    # Réponse unifiée pour l'erreur NoCandidatesError (Turbo Stream + HTML fallback)
    def respond_with_no_candidates(error)
      message = error.message
      respond_to do |format|
        format.turbo_stream { render_flash_stream(alert: message) }
        format.html { redirect_to @menu, alert: message, status: :see_other }
      end
    end
  end
end
