# UC4 — Toggle favori et rendu Turbo Stream associé
module Recipes
  module Favoritable
    extend ActiveSupport::Concern

    # POST /recipes/:id/toggle_favorite
    # UC4 : Toggle favori (ajoute si absent, supprime si présent)
    def toggle_favorite
      added = FavoriteRecipe.toggle_for(user: current_user, recipe: recipe)
      respond_to do |format|
        format.html { redirect_to recipe, notice: favorite_notice(added) }
        format.turbo_stream { render_favorite_turbo_stream(added) }
      end
    end

    private

    def favorite_notice(added)
      added ? "Recette ajoutée à vos favoris ⭐" : "Recette retirée de vos favoris"
    end

    def render_favorite_turbo_stream(added)
      favorite_btn_id = "favorite-btn-#{recipe.id}"
      render turbo_stream: turbo_stream.replace(
        favorite_btn_id,
        partial: "recipes/favorite_button",
        locals: {
          recipe: recipe,
          is_favorited: added,
          container_id: favorite_btn_id,
          compact: params[:compact] == "true",
          show_page: params[:show_page] == "true"
        }
      )
    end
  end
end
