# frozen_string_literal: true

require "rails_helper"

# Panneau « Ingrédients détectés par l'IA » du formulaire d'un brouillon : ce
# qu'il affiche des unités, et ce qu'il fait des quantités qu'il ne sait pas
# convertir.
RSpec.describe "Panneau des ingrédients détectés par l'IA", type: :request do
  let(:admin) { create(:user, admin: true) }

  before { sign_in admin }

  # Un brouillon dont l'IA a détecté les ingrédients passés en argument.
  def draft_with(*ai_ingredients)
    create(:recipe, status: :draft, ai_raw_data: { "ingredients" => ai_ingredients })
  end

  def ai_ingredient(name, quantity, unit = nil)
    { "name" => name, "quantity" => quantity, "unit" => unit }
  end

  describe "affichage des unités" do
    it "accole son unité de base à l'ingrédient trouvé" do
      create(:ingredient, name: "Farine", unit_group: :mass, base_unit: "g")

      get edit_recipe_path(draft_with(ai_ingredient("farine", 250, "g")))

      expect(response.body).to include("ai-row__unit")
      expect(response.body).to match(/Farine\s*<span class="ai-row__unit">\(g\)<\/span>/)
    end

    it "accole aussi son unité à chaque suggestion approchante" do
      create(:ingredient, name: "Jambon blanc", unit_group: :count, base_unit: "piece", piece_weight_g: 40)

      get edit_recipe_path(draft_with(ai_ingredient("jambon", 2)))

      expect(response.body).to include("Ressemble à")
      expect(response.body).to match(/Jambon blanc\s*<span class="ai-row__unit">\(piece\)<\/span>/)
    end
  end

  describe "quantité non convertible" do
    # Sans poids unitaire, « 2 » ne sait pas devenir des grammes : la quantité
    # brute part quand même dans le formulaire, mais l'unité passe en alerte.
    it "signale l'unité quand la conversion échoue" do
      create(:ingredient, name: "Jambon cru", unit_group: :mass, base_unit: "g")

      get edit_recipe_path(draft_with(ai_ingredient("jambon cru", 2)))

      expect(response.body).to include("ai-row__unit--mismatch")
      # Le titre voyage dans un attribut HTML : les apostrophes y sont échappées
      expect(response.body).to include(ERB::Util.html_escape(I18n.t("recipes.ai_panel.unit_mismatch")))
      expect(response.body).to include('data-ai-panel-converted="false"')
    end

    it "ne signale rien quand le poids unitaire fait le pont" do
      create(:ingredient, name: "Jambon cru", unit_group: :mass, base_unit: "g", piece_weight_g: 20)

      get edit_recipe_path(draft_with(ai_ingredient("jambon cru", 2)))

      expect(response.body).not_to include("ai-row__unit--mismatch")
      expect(response.body).to include('data-ai-panel-converted="true"')
      # 2 tranches de 20 g : la quantité posée dans le formulaire est en grammes
      expect(response.body).to include('data-ai-panel-quantity-base="40.0"')
    end

    it "convertit aussi dans l'autre sens, d'une masse vers un décompte" do
      create(:ingredient, name: "Œuf", unit_group: :count, base_unit: "piece", piece_weight_g: 50)

      get edit_recipe_path(draft_with(ai_ingredient("œuf", 200, "g")))

      expect(response.body).to include('data-ai-panel-quantity-base="4.0"')
    end
  end

  # Le poids voyage jusqu'au bouton : c'est le contrôleur Stimulus qui convertit
  # lorsque l'utilisatrice tranche elle-même entre deux suggestions.
  it "transmet le poids unitaire des suggestions au panneau" do
    create(:ingredient, name: "Jambon blanc", unit_group: :count, base_unit: "piece", piece_weight_g: 40)

    get edit_recipe_path(draft_with(ai_ingredient("jambon", 2)))

    expect(response.body).to include('data-ai-panel-piece-weight="40.0"')
  end
end
