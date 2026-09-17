# frozen_string_literal: true

# Un foyer : les comptes qui partagent les mêmes menus et la même liste de courses.
#
# Chaque compte appartient toujours à un foyer, souvent d'une seule personne —
# il naît avec le compte (cf. User). Il n'existe donc aucun cas « sans foyer » à
# traiter : seul dans son foyer, on vit exactement comme avant le partage.
#
# Tous les membres sont égaux : chacun compose, valide, coche, invite et retire.
# On entre par le lien d'invitation (invite_token) ; on sort en quittant le
# foyer, ou en en étant retiré par un autre membre.
class Household < ApplicationRecord
  # Départ refusé par une règle du foyer (le dernier membre ne peut pas partir).
  # Erreur ATTENDUE, que le contrôleur transforme en message — même esprit que
  # Menu::InvalidTransitionError.
  class MembershipError < StandardError; end

  # === Associations ===

  # Un foyer ne disparaît qu'une fois vide (cf. User#destroy_household_if_empty) :
  # en détruire un qui a encore des membres est un bug, pas un cas à gérer.
  has_many :members, class_name: "User", inverse_of: :household, dependent: :restrict_with_exception

  has_many :menus, dependent: :destroy

  # Le jeton du lien d'invitation. Le renouveler (regenerate_invite_token) rend
  # l'ancien lien inutilisable.
  has_secure_token :invite_token

  # === Méthodes d'instance ===

  # Le foyer compte-t-il plusieurs membres ? Seul, on n'a rien à répartir : la
  # liste de courses n'affiche alors rien de « Je m'en occupe ».
  def shared?
    members.many?
  end

  # Accueille un compte dans ce foyer, qu'il quitte alors son foyer actuel.
  #
  # S'il y vivait seul, ses menus le suivent et rejoignent l'historique : ce foyer
  # n'a qu'un menu actif et qu'un brouillon, et ce sont les siens qui restent. Le
  # foyer quitté, désormais vide, disparaît. S'il partageait son foyer, les menus
  # restent à ceux qui y demeurent, et les articles qu'il y avait pris redeviennent
  # libres.
  #
  # @param user [User]
  # @raise [ActiveRecord::RecordInvalid] si le compte ne peut pas être enregistré
  def admit!(user)
    return if user.household_id == id

    transaction do
      previous = user.household
      user.update!(household: self)

      if previous.members.exists?
        previous.release_claims_of(user)
      else
        previous.menus.where.not(status: :archived).find_each(&:archive!)
        previous.menus.update_all(household_id: id)
        previous.destroy!
      end
    end
  end

  # Fait sortir un membre du foyer, qu'il parte de lui-même ou qu'un autre membre
  # le retire : il repart avec un foyer neuf et vide, les menus restent à ceux qui
  # demeurent, et les articles qu'il avait pris redeviennent libres.
  #
  # @param member [User] un membre de ce foyer — l'appelant l'a cherché parmi
  #   `members`, ce qui fait office d'autorisation
  # @raise [MembershipError] s'il est le dernier membre du foyer
  def release!(member)
    raise MembershipError, "Tu es la seule personne de ton foyer : il n'y a rien à quitter." if members.count == 1

    transaction do
      release_claims_of(member)
      member.update!(household: Household.new)
    end
  end

  protected

  # Rend libres les articles qu'un membre qui s'en va avait pris sur les listes
  # du foyer : sans quoi personne ne les achèterait, chacun les croyant pris.
  # Protégée plutôt que privée : admit! l'appelle sur le foyer quitté.
  # @param member [User]
  def release_claims_of(member)
    GroceryItem.joins(:menu).where(menus: { household_id: id }, claimed_by: member)
               .find_each { |item| item.release!(member) }
  end
end
