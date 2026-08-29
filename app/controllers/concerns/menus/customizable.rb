# UC2 — Personnalisation : remplacement, régénération et dosage des moments.
# L'ajout d'une recette CHOISIE passe par le catalogue, où l'utilisatrice filtre
# le moment qu'elle veut compléter — voir Recipes::DraftManageable.
module Menus
  module Customizable
    extend ActiveSupport::Concern

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
    # Re-génère les repas du brouillon avec de nouveaux paramètres. Deux portes
    # d'entrée (UC7, chapitre 3) :
    # - le formulaire de re-génération transmet une répartition complète dans
    #   menu[meal_counts] — elle devient la nouvelle commande du menu ;
    # - le panneau de réglages (changement de régime) n'en transmet pas : la
    #   commande mémorisée (requested_meal_counts) est rejouée à l'identique.
    # Des pools trop maigres ne font jamais échouer la re-génération : le
    # brouillon expose les manques à combler depuis le catalogue.
    def regenerate
      meal_counts = regeneration_meal_counts
      return render_edit_with_alert(MenusController::NO_MEALS_ALERT) unless meal_counts.any?

      @menu.update!(menu_params)
      Menus::ComposeMealsService.call(menu: @menu, meal_counts: meal_counts)

      redirect_to @menu, notice: "Menu re-généré avec les nouveaux paramètres !", status: :see_other
    end

    # PATCH /menus/:id/adjust_meal_count
    # Ajuste d'un cran le nombre de repas d'un moment depuis le panneau de
    # réglages du brouillon (params : meal_type, delta), UC7.
    #
    # C'est un PAS qui est transmis, jamais une valeur cible : la composition
    # réelle n'est connue que du serveur — un compteur envoyé par la page
    # pourrait être périmé (repas retiré depuis une carte) et ajouterait alors
    # des repas que personne n'a demandés.
    def adjust_meal_count
      return head :bad_request unless MealTypes::MEAL_TYPES.include?(params[:meal_type])

      Menus::AdjustMealCountService.call(menu:      @menu,
                                         meal_type: params[:meal_type],
                                         delta:     params[:delta].to_i.clamp(-1, 1))
      @menu_recipes = @menu.meals_for_display

      respond_to do |format|
        format.turbo_stream { render "menus/refresh_draft" }
        format.html { redirect_to @menu }
      end
    rescue Menus::NoCandidatesError => error
      respond_with_no_candidates(error)
    end

    private

    # La commande à honorer pour cette re-génération : une répartition
    # transmise prime ; à défaut, celle mémorisée sur le menu. (Un brouillon
    # d'avant les quotas n'a ni l'une ni l'autre : on invite alors à décrire
    # sa semaine dans le formulaire de re-génération, pré-rempli par la vue.)
    def regeneration_meal_counts
      transmitted = MealCounts.from_hash(params.dig(:menu, :meal_counts))

      transmitted.any? ? transmitted : @menu.requested_counts
    end

    # Ré-affiche le formulaire de re-génération avec un message d'alerte.
    def render_edit_with_alert(message)
      flash.now[:alert] = message
      render :edit, status: :unprocessable_entity
    end

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
