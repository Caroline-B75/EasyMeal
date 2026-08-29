# frozen_string_literal: true

require "rails_helper"

# L'estimation d'une densité par l'IA. Ce qui compte ici n'est pas la valeur
# rendue — l'IA est simulée — mais ce qu'on en fait : elle n'entre en base que
# marquée « estimée », et rien de ce qui peut mal tourner n'interrompt l'import
# auquel elle est accrochée.
RSpec.describe Ingredients::EstimateDensityJob, type: :job do
  let(:farine) { create(:ingredient, name: "Farine", unit_group: :mass, base_unit: "g") }

  # IA scellée par défaut : un appel non simulé se voit.
  before do
    allow(Recipes::ClaudeClient).to receive(:call) do
      raise "Appel à l'IA non simulé dans cet exemple"
    end
  end

  def stub_claude(answer)
    allow(Recipes::ClaudeClient).to receive(:call).and_return(answer)
  end

  it "écrit la densité estimée en disant qu'elle vient de l'IA" do
    stub_claude("density_g_per_ml" => 0.55)

    described_class.perform_now(farine)

    expect(farine.reload).to have_attributes(density_g_per_ml: 0.55, density_source: "ai")
  end

  it "demande la densité de cet ingrédient, et de lui seul" do
    stub_claude("density_g_per_ml" => 0.55)

    described_class.perform_now(farine)

    expect(Recipes::ClaudeClient).to have_received(:call)
      .with(Ingredients::DensityPrompt.request("Farine"))
  end

  # Un second appel serait facturé pour un résultat déjà obtenu — et écraserait
  # une valeur curatée par une estimation.
  it "ne redemande pas une densité déjà connue" do
    farine.update!(density_g_per_ml: 0.6, density_source: :manual)

    described_class.perform_now(farine)

    expect(Recipes::ClaudeClient).not_to have_received(:call)
    expect(farine.reload).to have_attributes(density_g_per_ml: 0.6, density_source: "manual")
  end

  # Le prompt autorise l'IA à refuser : mieux vaut pas de densité qu'une densité
  # inventée, et l'absence se signale déjà d'elle-même à l'import.
  it "n'écrit rien quand l'IA ne sait pas répondre" do
    stub_claude("density_g_per_ml" => nil)

    described_class.perform_now(farine)

    expect(farine.reload.density_g_per_ml).to be_nil
  end

  # La validation borne ce que l'IA peut écrire : une valeur aberrante est
  # refusée, pas enregistrée, et le job se termine sans bruit.
  it "refuse une densité hors des bornes alimentaires" do
    stub_claude("density_g_per_ml" => 55)

    expect { described_class.perform_now(farine) }.not_to raise_error

    expect(farine.reload.density_g_per_ml).to be_nil
  end

  # L'estimation est un confort : sa panne ne doit pas faire échouer le job qui
  # l'a lancée, ni la conversion qui s'en passait déjà.
  it "encaisse une panne de l'IA sans échouer" do
    allow(Recipes::ClaudeClient).to receive(:call).and_raise(Recipes::ExtractionError, "API muette")

    expect { described_class.perform_now(farine) }.not_to raise_error

    expect(farine.reload.density_g_per_ml).to be_nil
  end
end
