# frozen_string_literal: true

module Recipes
  # UC4 : Gestion des avis sur les recettes
  # Réservé aux utilisateurs connectés
  class ReviewsController < ApplicationController
    before_action :authenticate_user!
    before_action :set_recipe

    # POST /recipes/:recipe_id/reviews
    # Crée ou met à jour l'avis de l'utilisateur courant
    def create
      @review = Review.create_or_update_for(
        user: current_user,
        recipe: @recipe,
        rating: params[:rating].to_i,
        content: params[:content]
      )

      if @review.persisted?
        respond_to do |format|
          format.turbo_stream do
            render turbo_stream: [
              turbo_stream.update("review-form-container", ""),
              turbo_stream.prepend("reviews-list", partial: "recipes/review_card", locals: { review: @review, current_user: current_user })
            ]
          end
          format.html { redirect_to @recipe, notice: "Ton avis a été enregistré 🌟" }
        end
      else
        redirect_to @recipe, alert: "Erreur : #{@review.errors.full_messages.join(', ')}"
      end
    end

    # DELETE /recipes/:recipe_id/reviews/:id
    # Supprime l'avis de l'utilisateur courant (ownership vérifié)
    def destroy
      review = @recipe.reviews.find_by(id: params[:id], user: current_user)

      if review&.destroy
        respond_to do |format|
          format.turbo_stream do
            render turbo_stream: [
              turbo_stream.remove("review_#{review.id}"),
              turbo_stream.update("review-form-container", partial: "recipes/review_form", locals: { recipe: @recipe })
            ]
          end
          format.html { redirect_to @recipe, notice: "Ton avis a été supprimé" }
        end
      else
        redirect_to @recipe, alert: "Impossible de supprimer l'avis"
      end
    end

    private

    def set_recipe
      @recipe = Recipe.find(params[:recipe_id])
    end
  end
end
