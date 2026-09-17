# frozen_string_literal: true

require "rails_helper"

# Le foyer : les comptes qui partagent menus et liste de courses. On y entre par
# le lien d'invitation (admit!), on en sort de soi-même ou retiré par un autre
# membre (release!).
RSpec.describe Household, type: :model do
  let(:host) { create(:user) }
  let(:household) { host.household }

  it "tire un jeton d'invitation à sa création" do
    expect(household.invite_token).to be_present
  end

  describe "#admit!" do
    it "fait entrer le compte dans le foyer" do
      guest = create(:user)

      household.admit!(guest)

      expect(guest.reload.household).to eq(household)
      expect(household.members).to contain_exactly(host, guest)
    end

    # Le foyer d'accueil n'a qu'un menu actif et qu'un brouillon : ce sont les
    # siens qui restent, ceux de l'arrivant rejoignent l'historique.
    it "verse les menus d'un arrivant qui vivait seul dans l'historique du foyer" do
      host_active = create(:menu, user: host, status: :active)
      host_draft = create(:menu, user: host, status: :draft)
      guest = create(:user)
      guest_menus = %i[active draft archived].map { |status| create(:menu, user: guest, status: status) }
      previous_household = guest.household

      household.admit!(guest)

      expect(guest_menus.map(&:reload)).to all(be_status_archived)
      expect(guest_menus.map(&:household_id).uniq).to eq([ household.id ])
      expect(host_active.reload).to be_status_active
      expect(host_draft.reload).to be_status_draft
      expect(Household.exists?(previous_household.id)).to be(false)
    end

    it "laisse ses menus au foyer quitté quand d'autres membres y restent" do
      guest = create(:user)
      housemate = create(:user)
      guest.household.admit!(housemate)
      shared_menu = create(:menu, user: guest, status: :active)

      household.admit!(guest)

      expect(shared_menu.reload.household).to eq(housemate.household)
      expect(shared_menu).to be_status_active
      expect(guest.reload.menus).to be_empty
    end

    it "ne change rien pour un membre du foyer" do
      menu = create(:menu, user: host, status: :active)

      household.admit!(host)

      expect(host.reload.household).to eq(household)
      expect(menu.reload).to be_status_active
    end
  end

  describe "#release!" do
    it "donne un foyer neuf et vide au membre qui part, les menus restent au foyer" do
      member = create(:user)
      household.admit!(member)
      menu = create(:menu, user: host)

      household.release!(member)

      expect(member.reload.household).not_to eq(household)
      expect(member.menus).to be_empty
      expect(host.reload.menus).to eq([ menu ])
    end

    it "refuse le départ du dernier membre" do
      expect { household.release!(host) }.to raise_error(Household::MembershipError)
      expect(host.reload.household).to eq(household)
    end

    # Personne n'achèterait un article pris par quelqu'un qui n'est plus là.
    it "rend libres les articles que le membre avait pris" do
      member = create(:user)
      household.admit!(member)
      item = create(:grocery_item, menu: create(:menu, user: host, status: :active), claimed_by: member)

      household.release!(member)

      expect(item.reload.claimed_by).to be_nil
    end
  end

  describe "#admit! depuis un foyer partagé" do
    it "rend libres les articles pris sur les listes du foyer quitté" do
      guest = create(:user)
      housemate = create(:user)
      guest.household.admit!(housemate)
      item = create(:grocery_item, menu: create(:menu, user: housemate, status: :active), claimed_by: guest)

      household.admit!(guest)

      expect(item.reload.claimed_by).to be_nil
    end
  end

  describe "#shared?" do
    it "n'est partagé qu'à partir de deux membres" do
      expect(household).not_to be_shared

      household.admit!(create(:user))

      expect(household.reload).to be_shared
    end
  end
end
