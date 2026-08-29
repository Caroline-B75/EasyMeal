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
      format.turbo_stream { success ? render_created_tag : render_tag_errors }
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
      format.turbo_stream { render turbo_stream: refreshed_tags_list }
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

  # Tag créé : la liste se rafraîchit — il apparaît dans son groupe — et le
  # formulaire se vide, prêt pour la saisie suivante.
  def render_created_tag
    render turbo_stream: [ refreshed_tags_list, tag_form(Tag.new) ]
  end

  # Échec : seul le formulaire est réaffiché, avec ses erreurs et les valeurs
  # saisies conservées.
  def render_tag_errors
    render turbo_stream: tag_form(@tag), status: :unprocessable_entity
  end

  # La liste des tags telle qu'elle doit réapparaître après toute modification.
  # Partagée par la création et la mise à jour, qui la reconstruisaient à
  # l'identique.
  def refreshed_tags_list
    turbo_stream.replace("tags_list", partial: "tags/tags_list",
                                      locals: { tags: Tag.alphabetical,
                                                recipe_counts: recipe_counts_by_tag })
  end

  def tag_form(tag)
    turbo_stream.replace("new_tag_form", partial: "tags/new_tag_form",
                                         locals: { tag: tag, autofocus: true })
  end

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
