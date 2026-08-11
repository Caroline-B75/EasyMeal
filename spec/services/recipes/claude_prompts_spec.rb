# frozen_string_literal: true

require "rails_helper"

# Spec de Recipes::ClaudePrompts, extrait d'ExtractorService avec la
# construction des prompts. Aucun réseau ici : ces exemples ne lisent que du
# texte, ce qui est précisément l'intérêt du découpage.
#
# Ils verrouillent la correction DRY de l'étape : les quatre « règles strictes »
# étaient recopiées dans le prompt texte et dans le prompt photo, si bien qu'une
# correction apportée d'un seul côté faisait silencieusement diverger l'import
# URL de l'import photo.
RSpec.describe Recipes::ClaudePrompts do
  describe ".text_messages" do
    subject(:message) { described_class.text_messages("Tarte aux poireaux, 200 g de farine.").first }

    it "adresse à l'IA un unique message utilisateur portant le texte de la recette" do
      expect(described_class.text_messages("Une recette").size).to eq(1)
      expect(message[:role]).to eq("user")
      expect(message[:content]).to include(
        "Extrait les informations de cette recette",
        "Texte de la recette :",
        "Tarte aux poireaux, 200 g de farine."
      )
    end

    # Montrer le format attendu vaut mieux que le décrire — encore faut-il que
    # l'exemple soit du JSON valide, et qu'il porte les champs que la revue de
    # l'import exploite (voir RecipeImportsController#build_draft_recipe).
    it "montre un exemple de JSON valide portant tous les champs attendus" do
      example = JSON.parse(message[:content][/^\{.*\}$/])

      expect(example.keys).to contain_exactly(
        "name", "description", "default_servings", "prep_time_minutes", "cook_time_minutes",
        "total_time_minutes", "difficulty", "diet", "appliance", "instructions",
        "suggested_tags", "ingredients"
      )
      expect(example["ingredients"].first.keys).to contain_exactly("name", "quantity", "unit")
    end

    it "interdit d'inventer ce que le texte ne dit pas" do
      expect(message[:content]).to include("Ne jamais inventer d'information absente du texte")
    end
  end

  describe ".photo_messages" do
    subject(:content) { described_class.photo_messages("QUJD", "image/png").first[:content] }

    it "montre l'image avant la consigne, encodée en base64 avec son media_type" do
      expect(content.first).to eq(
        type: "image", source: { type: "base64", media_type: "image/png", data: "QUJD" }
      )
      expect(content.last[:type]).to eq("text")
      expect(content.last[:text]).to start_with("Lis cette photo de recette")
    end

    it "interdit d'inventer ce que la photo ne montre pas" do
      expect(content.last[:text]).to include("Ne jamais inventer d'information absente de la photo")
    end
  end

  describe ".ingredients_messages" do
    subject(:content) { described_class.ingredients_messages([ "200 g de farine", "3 oeufs" ]).first[:content] }

    it "liste les ingrédients à structurer, un par ligne" do
      expect(content).to include("Ingrédients :\n- 200 g de farine\n- 3 oeufs")
    end

    # Seule demande où l'on attend un tableau : le repli d'ExtractorService se
    # déclenche sur toute autre forme de réponse.
    it "demande un tableau JSON, et lui seul" do
      expect(content).to include("Retourne UNIQUEMENT un tableau JSON valide, sans texte avant ou après.")
    end
  end

  # ── Règles strictes : une seule écriture pour les deux extractions ────────

  describe "règles strictes" do
    it "envoie exactement les mêmes contraintes de format au texte et à la photo" do
      text  = described_class.text_messages("Une recette").first[:content]
      photo = described_class.photo_messages("QUJD", "image/jpeg").first[:content].last[:text]

      expect(text).to include(described_class::STRICT_RULES)
      expect(photo).to include(described_class::STRICT_RULES)
    end

    # Une valeur hors enum est silencieusement effacée à la création du brouillon
    # (RecipeImportsController#valid_enum) : la consigne doit donc énumérer
    # exactement ce que Recipe accepte, ni plus ni moins.
    it "énumère exactement les valeurs acceptées par les enums de Recipe" do
      expect(quoted_values_of("difficulty")).to eq(Recipe.difficulties.keys)
      expect(quoted_values_of("diet")).to eq(Recipe.diets.keys)
    end

    # Valeurs entre guillemets d'une règle, dans l'ordre où elles sont annoncées.
    def quoted_values_of(field)
      described_class::STRICT_RULES[/^- #{field} : (.+)$/, 1].scan(/"([^"]+)"/).flatten
    end
  end
end
