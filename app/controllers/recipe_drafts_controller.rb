class RecipeDraftsController < ApplicationController
  before_action :authenticate_user!

  # Tris proposés sur la liste des brouillons : clé d'URL → libellé du sélecteur.
  # L'ordre du hash est celui des options affichées, et cette liste est la seule
  # source de vérité — le contrôleur l'applique, la vue l'affiche
  # (voir RecipesHelper#draft_sort_options).
  SORTS = {
    "recent" => "Plus récentes d'abord",
    "oldest" => "Plus anciennes d'abord",
    "ready"  => "Prêtes à valider d'abord",
    "todo"   => "À compléter d'abord"
  }.freeze

  DEFAULT_SORT = "recent".freeze

  # Les deux tris par statut classent les brouillons prêts avant ceux à compléter.
  STATUS_SORTS = %w[ready todo].freeze

  def index
    authorize :recipe_draft
    @sort = SORTS.key?(params[:sort]) ? params[:sort] : DEFAULT_SORT
    @recipes = sorted_drafts
  end

  def destroy
    @recipe = Recipe.draft.find(params[:id])
    authorize @recipe, policy_class: RecipeDraftPolicy
    @recipe.destroy
    redirect_to recipe_drafts_path, notice: "Brouillon supprimé."
  end

  private

  # La complétude d'un brouillon (Recipe#draft_ready?) se calcule en Ruby : elle
  # dépend des préparations et de champs hétérogènes, l'exprimer en SQL
  # dupliquerait la règle. Le tri par statut se fait donc en mémoire, sur une
  # base déjà triée par date pour que l'ordre reste stable dans chaque groupe.
  # Sans coût caché : la liste des imports en attente est courte et tout est
  # préchargé.
  def sorted_drafts
    drafts = draft_scope.order(created_at: @sort == "oldest" ? :asc : :desc).to_a
    return drafts unless STATUS_SORTS.include?(@sort)

    ready, todo = drafts.partition(&:draft_ready?)
    @sort == "ready" ? ready + todo : todo + ready
  end

  # Précharge les préparations (calcul de complétude) et les deux blobs que la
  # vignette peut servir — photo de présentation, sinon page photographiée à
  # l'import — pour éviter les requêtes N+1 sur la liste.
  def draft_scope
    Recipe.draft.includes(:preparations, photo_attachment: :blob, source_photo_attachment: :blob)
  end
end
