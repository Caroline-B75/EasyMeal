# frozen_string_literal: true

module Households
  # Le lien d'invitation, ouvert par la personne invitée : une page qui dit ce
  # qui va se passer, puis l'entrée dans le foyer.
  #
  # Connexion exigée. Devise mémorise le lien demandé et y ramène après la
  # connexion comme après la création du compte : la personne invitée n'a rien
  # à recopier.
  class InvitationsController < ApplicationController
    INVALID_LINK_ALERT = "Ce lien d'invitation ne fonctionne plus. Demande un nouveau lien.".freeze

    before_action :authenticate_user!
    before_action :set_household
    before_action :redirect_current_member

    # GET /foyer/rejoindre/:token
    def show; end

    # POST /foyer/rejoindre/:token
    def create
      @household.admit!(current_user)
      redirect_to household_path, notice: "Bienvenue dans le foyer !", status: :see_other
    end

    private

    # Un jeton inconnu est un lien renouvelé depuis, ou mal recopié.
    def set_household
      @household = Household.find_by(invite_token: params[:token].to_s)
      redirect_to root_path, alert: INVALID_LINK_ALERT, status: :see_other unless @household
    end

    # Un membre qui rouvre le lien (depuis la conversation où il l'a reçu) n'a
    # rien à confirmer.
    def redirect_current_member
      return unless current_user.household_id == @household.id

      redirect_to household_path, notice: "Tu fais déjà partie de ce foyer.", status: :see_other
    end
  end
end
