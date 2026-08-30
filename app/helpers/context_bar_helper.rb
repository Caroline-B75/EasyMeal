# Helper pour le composant Context Bar unifié
# Génère une navigation contextuelle (back-link ou breadcrumb) posée en haut du
# contenu, dans la gouttière libre à gauche de l'écran.
module ContextBarHelper
  # Génère un lien retour simple
  #
  # @param path [String] URL de destination
  # @param label [String] Texte du lien (ex: "Retour aux recettes")
  # @return [String] HTML du context bar
  #
  # @example
  #   context_bar_back(recipes_path, "Retour aux recettes")
  def context_bar_back(path, label)
    render partial: "shared/context_bar",
           locals: { mode: :back, path: path, label: label, crumbs: nil }
  end

  # Génère un fil d'Ariane hiérarchique
  #
  # @param crumbs [Array<Hash>] Liste des crumbs avec :label et :path (sauf le dernier)
  # @return [String] HTML du context bar
  #
  # @example Breadcrumb à 2 niveaux
  #   context_bar_breadcrumb([
  #     { label: "Mes menus", path: menus_path },
  #     { label: "Menu semaine" }
  #   ])
  def context_bar_breadcrumb(crumbs)
    render partial: "shared/context_bar",
           locals: { mode: :breadcrumb, path: nil, label: nil, crumbs: crumbs }
  end
end
