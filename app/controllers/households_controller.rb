# frozen_string_literal: true

# « Mon foyer » : qui partage les menus et la liste de courses, et le lien pour
# inviter quelqu'un.
#
# Le foyer affiché est toujours celui du compte connecté — aucun id dans l'URL,
# donc rien à autoriser au-delà de la connexion (même principe que
# ProfilesController).
class HouseholdsController < ApplicationController
  before_action :authenticate_user!

  # Courses habituelles montrées en aperçu sur « Mon foyer » ; les autres se
  # comptent (« + 4 autres »).
  USUAL_PREVIEW = 6

  # GET /foyer
  # Membres dans l'ordre du foyer, celui qui décide aussi de leurs couleurs
  # (cf. HouseholdsHelper#member_color).
  def show
    @household = current_user.household
    @members = @household.members.order(:created_at, :id)
    @usual_grocery_items = @household.usual_grocery_items.sorted.limit(USUAL_PREVIEW)
    @usual_grocery_items_count = @household.usual_grocery_items.count
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
