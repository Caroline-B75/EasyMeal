# frozen_string_literal: true

module Households
  # Départ d'un membre du foyer : le sien (« Quitter le foyer ») ou celui d'un
  # autre (« Retirer ») — tous les membres sont égaux.
  #
  # Le membre est cherché parmi ceux du foyer connecté : c'est ce qui autorise
  # l'action. Le compte d'un autre foyer répond 404.
  class MembersController < ApplicationController
    before_action :authenticate_user!

    # DELETE /foyer/membres/:id
    def destroy
      household = current_user.household
      member = household.members.find(params[:id])
      household.release!(member)

      redirect_to household_path, notice: departure_notice(member), status: :see_other
    rescue Household::MembershipError => e
      redirect_to household_path, alert: e.message, status: :see_other
    end

    private

    def departure_notice(member)
      return "Tu as quitté le foyer." if member == current_user

      "@#{member.username} ne fait plus partie du foyer."
    end
  end
end
