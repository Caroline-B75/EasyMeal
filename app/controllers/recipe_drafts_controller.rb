class RecipeDraftsController < ApplicationController
  before_action :authenticate_user!

  def index
    authorize :recipe_draft
    @recipes = Recipe.draft.includes(:photo_attachment).order(created_at: :desc)
  end

  def destroy
    @recipe = Recipe.draft.find(params[:id])
    authorize @recipe, policy_class: RecipeDraftPolicy
    @recipe.destroy
    redirect_to recipe_drafts_path, notice: "Brouillon supprimé."
  end
end
