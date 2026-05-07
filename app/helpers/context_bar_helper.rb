# Helper pour le composant Context Bar unifié
# Génère une barre de navigation contextuelle (back-link ou breadcrumb)
module ContextBarHelper
  # Génère un lien retour simple
  # 
  # @param path [String] URL de destination
  # @param label [String] Texte du lien (ex: "Retour aux recettes")
  # @param variant [Symbol] Variante CSS (:default, :narrow, :fluid, :compact, :borderless)
  # @return [String] HTML du context bar
  #
  # @example
  #   context_bar_back(recipes_path, "Retour aux recettes")
  #   context_bar_back(menus_path, "Mes menus", variant: :narrow)
  def context_bar_back(path, label, variant: :default)
    render partial: "shared/context_bar",
           locals: { mode: :back, path: path, label: label, crumbs: nil, variant: variant }
  end

  # Génère un fil d'Ariane hiérarchique
  # 
  # @param crumbs [Array<Hash>] Liste des crumbs avec :label et :path (sauf le dernier)
  # @param variant [Symbol] Variante CSS (:default, :narrow, :fluid, :compact, :borderless)
  # @return [String] HTML du context bar
  #
  # @example Breadcrumb à 2 niveaux
  #   context_bar_breadcrumb([
  #     { label: "Mes menus", path: menus_path },
  #     { label: "Menu semaine" }
  #   ])
  #
  # @example Breadcrumb à 3 niveaux
  #   context_bar_breadcrumb([
  #     { label: "Mes menus", path: menus_path },
  #     { label: "Menu semaine", path: menu_path(@menu) },
  #     { label: "Liste de courses" }
  #   ])
  def context_bar_breadcrumb(crumbs, variant: :default)
    render partial: "shared/context_bar",
           locals: { mode: :breadcrumb, path: nil, label: nil, crumbs: crumbs, variant: variant }
  end

  # Retourne les classes CSS pour le context bar selon la variante
  def context_bar_classes(variant)
    base = "context-bar"
    modifier = case variant
               when :narrow then "context-bar--narrow"
               when :fluid then "context-bar--fluid"
               when :compact then "context-bar--compact"
               when :borderless then "context-bar--borderless"
               else nil
               end
    [base, modifier].compact.join(" ")
  end
end
