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
      expect(response.body).to match(/Jambon blanc\s*<span class="ai-row__unit">\(pièce\)<\/span>/)
    end

    # Les unités s'affichent comme on les écrit en français, pas comme on les
    # stocke : l'ingrédient au « cac » se lit « càc », et la cuillère détectée
    # par l'IA se relit dans la même langue que lui.
    it "écrit les unités en français, des deux côtés de la ligne" do
      create(:ingredient, name: "Huile d'olive", unit_group: :spoon, base_unit: "cac")

      get edit_recipe_path(draft_with(ai_ingredient("huile d'olive", 3, "cas")))

      expect(response.body).to match(/ai-row__qty">3 càs</)
      expect(response.body).to match(/<span class="ai-row__unit">\(càc\)<\/span>/)
    end

    # Le cas de l'huile d'olive : le catalogue la compte en millilitres, la
    # recette en cuillères à soupe. La conversion passe, sans avertissement.
    it "convertit des cuillères vers un ingrédient au millilitre" do
      create(:ingredient, name: "Huile d'olive", unit_group: :volume, base_unit: "ml")

      get edit_recipe_path(draft_with(ai_ingredient("huile d'olive", 3, "cas")))

      expect(response.body).to include('data-ai-panel-quantity-base="45.0"')
      expect(response.body).to include('data-ai-panel-converted="true"')
      expect(response.body).not_to include("ai-row__unit--mismatch")
    end

    # « 1 c. à s. de farine » : la conversion passe par la densité, et si celle-ci
    # n'est qu'estimée, la ligne le dit — sans crier à l'erreur, la quantité est
    # exploitable.
    it "signale une conversion obtenue par une densité estimée" do
      create(:ingredient, name: "Farine", unit_group: :mass, base_unit: "g",
                          density_g_per_ml: 0.55, density_source: :ai)

      get edit_recipe_path(draft_with(ai_ingredient("farine", 1, "cas")))

      expect(response.body).to include("ai-row__unit--estimated")
      expect(response.body).to include(ERB::Util.html_escape(I18n.t("recipes.ai_panel.unit_estimated")))
      expect(response.body).to include('data-ai-panel-estimated="true"')
      expect(response.body).to include('data-ai-panel-quantity-base="8.25"')
      expect(response.body).not_to include("ai-row__unit--mismatch")
    end

    it "ne signale rien quand la densité a été vérifiée" do
      create(:ingredient, name: "Farine", unit_group: :mass, base_unit: "g",
                          density_g_per_ml: 0.55, density_source: :manual)

      get edit_recipe_path(draft_with(ai_ingredient("farine", 1, "cas")))

      expect(response.body).not_to include("ai-row__unit--estimated")
      expect(response.body).to include('data-ai-panel-estimated="false"')
    end

    # Les brouillons créés avant la normalisation à l'extraction portent encore
    # les unités accentuées : le panneau doit continuer de les lire, et les
    # transmettre au contrôleur Stimulus sous leur forme canonique.
    it "relit les unités accentuées des anciens brouillons" do
      create(:ingredient, name: "Huile d'olive", unit_group: :spoon, base_unit: "cac")

      get edit_recipe_path(draft_with(ai_ingredient("huile d'olive", 3, "càs")))

      expect(response.body).to include('data-ai-panel-unit="cas"')
      expect(response.body).to include('data-ai-panel-quantity-base="9.0"')
      expect(response.body).to include('data-ai-panel-converted="true"')
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

  # Le groupe d'unités de l'ingrédient trouvé accompagne le bouton « Ajouter » :
  # c'est lui qui dit au contrôleur Stimulus si la ligne du formulaire peut
  # s'ouvrir dans l'unité de la recette (« 3 càs ») ou seulement en unité de base.
  it "transmet le groupe d'unités de l'ingrédient trouvé" do
    create(:ingredient, name: "Huile d'olive", unit_group: :spoon, base_unit: "cac")

    get edit_recipe_path(draft_with(ai_ingredient("huile d'olive", 3, "cas")))

    expect(response.body).to include('data-ai-panel-unit-group="spoon"')
  end

  # La table des unités (Units.table) traverse une seule fois, sur le formulaire :
  # les contrôleurs Stimulus y lisent facteurs et libellés au lieu d'en garder
  # une copie en JS.
  it "pose la table des unités sur le formulaire" do
    create(:ingredient, name: "Huile d'olive", unit_group: :spoon, base_unit: "cac")

    get edit_recipe_path(draft_with(ai_ingredient("huile d'olive", 3, "cas")))

    expect(response.body).to include(ERB::Util.html_escape(Units.table.to_json))
  end

  # Un formulaire refusé revient avec ses erreurs, et le panneau IA doit revenir
  # avec lui : c'est justement là qu'on a besoin des suggestions pour corriger.
  describe "après une soumission refusée" do
    let(:draft) { draft_with(ai_ingredient("farine", 250, "g")) }

    # Le formulaire, moins les ingrédients. `extra` sert à y glisser le drapeau
    # de publication ou à casser un champ.
    def submit(recipe_attrs = {}, extra = {})
      patch recipe_path(draft), params: {
        recipe: { name: draft.name, diet: draft.diet,
                  default_servings: draft.default_servings }.merge(recipe_attrs)
      }.merge(extra)
    end

    before { create(:ingredient, name: "Farine", unit_group: :mass, base_unit: "g") }

    # Le cas courant : on clique « Publier » avant d'avoir repris les
    # ingrédients. La validation « au moins un ingrédient » ne vise que les
    # recettes publiées, c'est donc ici qu'elle se déclenche — et l'objet en
    # mémoire porte déjà status: published alors que la base est restée en
    # brouillon.
    it "réaffiche le panneau IA quand la publication échoue faute d'ingrédient" do
      submit({}, _publish: "1")

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.body).to include("Une recette doit contenir au moins un ingrédient")
      expect(response.body).to include("Ingrédients détectés par l'IA")
      expect(response.body).to include("Farine")
      expect(draft.reload).to be_draft
    end

    it "réaffiche le panneau IA quand la sauvegarde du brouillon échoue" do
      submit(name: "")

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.body).to include("Ingrédients détectés par l'IA")
      expect(response.body).to include("Farine")
    end
  end
end
