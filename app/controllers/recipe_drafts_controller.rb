class RecipeDraftsController < ApplicationController
  before_action :authenticate_user!

  def index
    authorize :recipe_draft
    # Précharge les préparations (calcul de complétude) et le blob photo (mini-photo Cloudinary)
    # pour éviter les requêtes N+1 sur la liste.
    @recipes = Recipe.draft
                     .includes(:preparations, photo_attachment: :blob)
                     .order(created_at: :desc)
  end

  def destroy
    @recipe = Recipe.draft.find(params[:id])
    authorize @recipe, policy_class: RecipeDraftPolicy
    @recipe.destroy
    redirect_to recipe_drafts_path, notice: "Brouillon supprimé."
  end
end
