# frozen_string_literal: true

# « Mon foyer » : qui partage les menus et la liste de courses, et le lien pour
# inviter quelqu'un.
#
# Le foyer affiché est toujours celui du compte connecté — aucun id dans l'URL,
# donc rien à autoriser au-delà de la connexion (même principe que
# ProfilesController).
class HouseholdsController < ApplicationController
  before_action :authenticate_user!

  # GET /foyer
  def show
    @household = current_user.household
    @members = @household.members.order(:created_at)
  end

  # PATCH /foyer/renew_invitation
  # Un lien qui a circulé plus loin que prévu se remplace : l'ancien cesse
  # aussitôt de fonctionner.
  def renew_invitation
    current_user.household.regenerate_invite_token
    redirect_to household_path, notice: "Nouveau lien d'invitation créé : l'ancien ne fonctionne plus.",
                                status: :see_other
  end
end
