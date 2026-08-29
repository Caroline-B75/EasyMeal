require "rails_helper"

RSpec.describe GreetingService do
  let(:user) { build(:user, first_name: "Caroline", gender: "female") }

  describe "::GREETING_TEXTS" do
    it "conserve tous les textes d'accueil historiques" do
      expect(described_class::GREETING_TEXTS.size).to eq(39)
      expect(described_class::GREETING_TEXTS).to include(
        "Hello %{name} ! Mijotons quelque chose ensemble !",
        "Hello %{name}, ton frigo attend tes talents !",
        "Hey %{name} ! Si Etchebest voyait ça, il dirait : putain c'est bon !"
      )
    end
  end

  describe "#random_greeting" do
    it "tire une paire texte/sous-texte dans le contexte demandé" do
      service = described_class.new(user, context: :pending_revalidation)
      expected_pair = [
        "Hello %{name} ! %{ready} à mitonner de bons petits plats ?",
        "Tes ajustements attendent validation avant de rafraîchir les courses."
      ]

      allow(service).to receive(:greeting_pairs).and_return([ expected_pair ])

      greeting = service.random_greeting

      expect(greeting.text).to eq("Hello Caroline ! prête à mitonner de bons petits plats ?")
      expect(greeting.subtext).to eq("Tes ajustements attendent validation avant de rafraîchir les courses.")
    end
  end
end
