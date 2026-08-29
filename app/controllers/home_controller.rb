class HomeController < ApplicationController
  def index
    return unless user_signed_in?

    load_user_menus
  end

  private

  # Charge le brouillon le plus récent et le menu actif de l'utilisateur
  def load_user_menus
    menu_includes = { menu_recipes: { recipe: :photo_attachment } }

    @active_menu = current_user.menus.active_menus.includes(menu_includes).first
    @draft = current_user.menus.status_draft.recent.includes(menu_includes).first
  end
end
