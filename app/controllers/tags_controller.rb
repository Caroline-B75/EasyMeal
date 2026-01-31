# Gestion des tags (admin only)
class TagsController < ApplicationController
  before_action :set_tag, only: [:edit, :update, :destroy]
  before_action :authorize_tag, only: [:index, :edit, :update, :destroy]

  # GET /tags
  # Liste tous les tags avec nombre de recettes
  def index
    @tags = Tag.alphabetical
  end

  # GET /tags/:id/edit
  # Formulaire d'édition d'un tag
  def edit
  end

  # PATCH/PUT /tags/:id
  # Mise à jour d'un tag (correction orthographe, etc.)
  # Supporte l'édition inline avec Turbo
  def update
    if @tag.update(tag_params)
      respond_to do |format|
        format.turbo_stream { render turbo_stream: turbo_stream.replace("tags_list", partial: "tags/tags_list", locals: { tags: Tag.alphabetical }) }
        format.html { redirect_to tags_path, notice: "Tag mis à jour avec succès." }
      end
    else
      respond_to do |format|
        format.turbo_stream { render turbo_stream: turbo_stream.replace("tags_list", partial: "tags/tags_list", locals: { tags: Tag.alphabetical }) }
        format.html { render :edit, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /tags/:id
  # Suppression d'un tag (retire le tag de toutes les recettes)
  def destroy
    @tag.destroy
    redirect_to tags_path, notice: "Tag supprimé avec succès."
  end

  private

  def set_tag
    @tag = Tag.find(params[:id])
  end

  def authorize_tag
    authorize @tag || Tag
  end

  def tag_params
    params.require(:tag).permit(:name)
  end
end
