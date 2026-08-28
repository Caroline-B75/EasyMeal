# frozen_string_literal: true

require "rails_helper"

# Une seule question, sur un seul ingrédient : la densité est une propriété de la
# farine, pas de la recette qui l'emploie.
RSpec.describe Ingredients::DensityPrompt do
  subject(:request) { described_class.request("Farine") }

  let(:prompt) { request[:messages].first[:content] }

  it "nomme l'ingrédient et attend une seule valeur, nullable" do
    expect(prompt).to include("Ingrédient : Farine")
    expect(request[:schema][:properties].keys).to eq([ :density_g_per_ml ])
    expect(request[:schema][:properties][:density_g_per_ml][:anyOf])
      .to eq([ { type: "number" }, { type: "null" } ])
    expect(request[:schema][:additionalProperties]).to be(false)
  end

  # Une densité inventée fausserait des quantités en silence ; une absence se
  # voit et se signale. Le prompt doit donc autoriser franchement le refus.
  it "autorise l'IA à ne pas répondre" do
    expect(prompt).to include("null")
  end

  # Une farine tassée pèse un tiers de plus : la mesure demandée est celle du
  # cuisinier, sinon la densité vaudrait pour une autre cuisine que la sienne.
  it "demande la mesure telle qu'on la fait en cuisine" do
    expect(prompt).to match(/ni tassé|foisonné/)
  end

  # Celle de l'import parlerait d'extraire des recettes : hors sujet ici.
  it "porte sa propre consigne système" do
    expect(request[:system]).to eq(described_class::SYSTEM)
    expect(request[:system]).not_to eq(Recipes::ClaudePrompts::SYSTEM)
  end
end
