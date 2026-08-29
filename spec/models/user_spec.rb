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
end
