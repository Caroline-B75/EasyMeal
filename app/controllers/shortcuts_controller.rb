# Cibles stables pour les raccourcis (shortcuts) du manifest PWA.
# Le manifest étant partagé et mis en cache par le navigateur, ses URLs ne
# peuvent pas être spécifiques à un utilisateur : ces actions résolvent le
# menu actif côté serveur puis redirigent vers la bonne page.
class ShortcutsController < ApplicationController
  before_action :authenticate_user!

  # Raccourci « Menu en cours » → menu actif, sinon liste des menus.
  def current_menu
    active = helpers.current_active_menu
    redirect_to active ? menu_path(active) : menus_path
  end

  # Raccourci « Liste de courses » → courses du menu actif, sinon liste des menus.
  def current_grocery
    active = helpers.current_active_menu
    redirect_to active ? grocery_menu_path(active) : menus_path
  end
end
