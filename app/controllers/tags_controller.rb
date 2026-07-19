# Gestion des tags (admin only)
class TagsController < ApplicationController
  before_action :set_tag, only: [ :edit, :update, :destroy ]
  before_action :authorize_tag, only: [ :index, :create, :edit, :update, :destroy ]

  # GET /tags
  # Liste tous les tags, groupés par type, avec nombre de recettes
  def index
    @tags = Tag.alphabetical
    @recipe_counts = recipe_counts_by_tag
  end

  # POST /tags
  # Création rapide d'un tag depuis la liste (édition à la volée)
  def create
    @tag = Tag.new(tag_params)
    success = @tag.save

    respond_to do |format|
      format.turbo_stream do
        if success
          # Liste rafraîchie (le tag apparaît dans son groupe) + formulaire vidé
          render turbo_stream: [
            turbo_stream.replace("tags_list", partial: "tags/tags_list",
              locals: { tags: Tag.alphabetical, recipe_counts: recipe_counts_by_tag }),
            turbo_stream.replace("new_tag_form", partial: "tags/new_tag_form",
              locals: { tag: Tag.new, autofocus: true })
          ]
        else
          # Formulaire réaffiché avec les erreurs, valeurs saisies conservées
          render turbo_stream: turbo_stream.replace("new_tag_form", partial: "tags/new_tag_form",
            locals: { tag: @tag, autofocus: true }), status: :unprocessable_entity
        end
      end
      format.html do
        if success
          redirect_to tags_path, notice: "Tag créé avec succès."
        else
          @tags = Tag.alphabetical
          @recipe_counts = recipe_counts_by_tag
          render :index, status: :unprocessable_entity
        end
      end
    end
  end

  # GET /tags/:id/edit
  # Formulaire d'édition d'un tag
  def edit
  end

  # PATCH/PUT /tags/:id
  # Mise à jour d'un tag (correction orthographe, etc.)
  # Supporte l'édition inline avec Turbo
  def update
    success = @tag.update(tag_params)

    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: turbo_stream.replace("tags_list", partial: "tags/tags_list",
locals: { tags: Tag.alphabetical, recipe_counts: recipe_counts_by_tag })
      end
      format.html do
        if success
          redirect_to tags_path, notice: "Tag mis à jour avec succès."
        else
          render :edit, status: :unprocessable_entity
        end
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

  # Nombre de recettes par tag en une seule requête (évite le N+1 en vue).
  # Clé = tag_id, valeur = nombre de recettes associées.
  def recipe_counts_by_tag
    RecipeTag.group(:tag_id).count
  end

  def authorize_tag
    authorize @tag || Tag
  end

  def tag_params
    params.require(:tag).permit(:name, :tag_type)
  end
end
