class HomeController < ApplicationController
  def index
    return unless user_signed_in?

    load_user_menus
  end

  private

  # Charge le brouillon le plus récent et le menu actif de l'utilisateur
  def load_user_menus
    @draft = current_user.menus.status_draft.recent.first
    @active_menu = current_user.menus.active_menus.first
  end
end
