require 'rails_helper'

RSpec.describe User, type: :model do
  it { should validate_presence_of(:email) }

  # UC7 — la semaine type mémorisée : la colonne jsonb ne se lit jamais à nu,
  # toujours à travers l'objet-valeur qui la normalise.
  describe "#preferred_meal_counts" do
    it "part d'une répartition vide tant que la semaine n'a pas été décrite" do
      expect(build(:user).preferred_meal_counts.any?).to be(false)
    end

    it "relit la répartition mémorisée, option petit-déjeuner comprise" do
      user = create(:user)
      user.update!(default_meal_counts: MealCounts.from_hash({ "breakfast" => 7, "dinner" => 5,
                                                               "same_breakfast" => "1" }).to_h)

      counts = user.reload.preferred_meal_counts

      expect(counts[:breakfast]).to eq(7)
      expect(counts[:dinner]).to eq(5)
      expect(counts.total).to eq(12)
      expect(counts.same_breakfast?).to be(true)
    end
  end

  # Un compte n'est jamais sans foyer : c'est ce qui dispense tout le reste de
  # l'application d'un cas particulier « pas encore de partage ».
  describe "foyer" do
    it "naît seul dans son propre foyer" do
      user = create(:user)

      expect(user.household).to be_persisted
      expect(user.household.members).to eq([ user ])
    end

    it "voit les menus de son foyer, quel que soit le membre qui les a composés" do
      user = create(:user)
      partner = create(:user)
      user.household.admit!(partner)
      menu = create(:menu, user: user)

      expect(partner.reload.menus).to eq([ menu ])
    end

    describe "suppression du compte" do
      it "emporte le foyer et ses menus quand il en était le dernier membre" do
        user = create(:user)
        menu = create(:menu, user: user)

        user.destroy!

        expect(Household.exists?(user.household_id)).to be(false)
        expect(Menu.exists?(menu.id)).to be(false)
      end

      it "laisse le foyer et ses menus aux membres qui restent" do
        user = create(:user)
        partner = create(:user)
        user.household.admit!(partner)
        menu = create(:menu, user: user)

        user.destroy!

        expect(partner.reload.menus).to eq([ menu ])
      end

      it "rend libres les articles de courses qu'il avait pris" do
        user = create(:user)
        partner = create(:user)
        user.household.admit!(partner)
        item = create(:grocery_item, menu: create(:menu, user: partner), claimed_by: user)

        user.destroy!

        expect(item.reload.claimed_by).to be_nil
      end
    end
  end
end
