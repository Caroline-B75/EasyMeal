# frozen_string_literal: true

require "rails_helper"

# « Mon foyer » : couleurs d'avatar, titre et résumé du bandeau.
RSpec.describe HouseholdsHelper, type: :helper do
  # Créée d'emblée : le rang d'un membre suit l'ancienneté des comptes
  let!(:caroline) { create(:user, first_name: "Caroline") }
  let(:household) { caroline.household }

  def join(first_name)
    create(:user, first_name: first_name).tap { |member| household.admit!(member) }
  end

  describe "#member_color" do
    it "donne à chaque membre d'un foyer une couleur différente, dans l'ordre du foyer" do
      marc = join("Marc")
      lea = join("Léa")

      expect([ caroline, marc, lea ].map { |member| helper.member_color(member) }).to eq([ 0, 1, 2 ])
    end

    it "fait repartir chaque foyer de la première couleur" do
      expect(helper.member_color(create(:user))).to eq(0)
    end
  end

  describe "#household_title" do
    it "dit les prénoms des membres" do
      expect(helper.household_title([ caroline ])).to eq("Caroline")
      expect(helper.household_title([ caroline, join("Marc") ])).to eq("Caroline & Marc")
      expect(helper.household_title([ caroline, join("Marc"), join("Léa") ])).to eq("Caroline, Marc & Léa")
    end
  end

  describe "#household_summary" do
    it "invite à partager quand on est seul" do
      expect(helper.household_summary(household, 3)).to start_with("Invite quelqu'un")
    end

    it "dit ce que le foyer partage, habituels compris" do
      join("Marc")

      expect(helper.household_summary(household, 0)).to eq("Vous partagez les menus et la liste de courses.")
      expect(helper.household_summary(household, 10))
        .to eq("Vous partagez les menus, la liste de courses et 10 courses habituelles.")
    end
  end
end
