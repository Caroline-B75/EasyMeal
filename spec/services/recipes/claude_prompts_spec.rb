# frozen_string_literal: true

require "rails_helper"

# Spec de Recipes::ClaudePrompts. Aucun réseau ici : ces exemples ne lisent que
# ce qu'on s'apprête à demander à l'IA — les messages et le schéma de sortie.
#
# Ils verrouillent deux mutualisations : les règles de format, autrefois
# recopiées dans le prompt texte et dans le prompt photo (une correction d'un
# seul côté faisait silencieusement diverger l'import URL de l'import photo), et
# le schéma que les deux extractions imposent désormais à la réponse.
RSpec.describe Recipes::ClaudePrompts do
  describe ".text_request" do
    subject(:message) { described_class.text_request("Tarte aux poireaux, 200 g de farine.")[:messages].first }

    it "adresse à l'IA un unique message utilisateur portant le texte de la recette" do
      expect(described_class.text_request("Une recette")[:messages].size).to eq(1)
      expect(message[:role]).to eq("user")
      expect(message[:content]).to include(
        "Extrait les informations de cette recette",
        "Texte de la recette :",
        "Tarte aux poireaux, 200 g de farine."
      )
    end

    # Le format n'est plus décrit ni supplié dans le prompt : c'est le schéma
    # joint à la requête qui le fait respecter par l'API.
    it "ne demande plus le format de la réponse dans le prompt" do
      expect(message[:content]).not_to match(/JSON/i)
    end

    it "interdit d'inventer ce que le texte ne dit pas" do
      expect(message[:content]).to include("Ne jamais inventer d'information absente du texte")
    end
  end

  describe ".photo_request" do
    subject(:content) { described_class.photo_request("QUJD", "image/png")[:messages].first[:content] }

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

  describe ".ingredients_request" do
    subject(:request) { described_class.ingredients_request([ "200 g de farine", "3 oeufs" ]) }

    it "liste les ingrédients à structurer, un par ligne" do
      expect(request[:messages].first[:content]).to include("Ingrédients :\n- 200 g de farine\n- 3 oeufs")
    end

    # La racine d'un schéma est forcément un objet : le tableau attendu voyage
    # donc sous une clé, qu'ExtractorService déballe.
    it "attend le tableau structuré sous la clé « ingredients »" do
      schema = request[:schema]

      expect(schema[:properties].keys).to eq([ :ingredients ])
      expect(schema[:properties][:ingredients][:type]).to eq("array")
    end
  end

  # ── Texte et photo : une seule écriture ─────────────────────────────────

  describe "consignes communes au texte et à la photo" do
    let(:text)  { described_class.text_request("Une recette")[:messages].first[:content] }
    let(:photo) { described_class.photo_request("QUJD", "image/jpeg")[:messages].first[:content].last[:text] }

    it "envoie exactement les mêmes règles de remplissage" do
      expect(text).to include(described_class::STRICT_RULES)
      expect(photo).to include(described_class::STRICT_RULES)
    end

    it "impose exactement le même schéma de sortie" do
      expect(described_class.photo_request("QUJD", "image/jpeg")[:schema])
        .to eq(described_class.text_request("Une recette")[:schema])
    end
  end

  # ── Schéma de la recette ────────────────────────────────────────────────

  describe "schéma de la recette" do
    subject(:schema) { described_class.text_request("Une recette")[:schema] }

    # Les champs sont exactement ceux que la revue de l'import exploite
    # (RecipeImportsController#build_draft_recipe).
    it "décrit un objet strict portant tous les champs attendus" do
      expect(schema[:properties].keys).to contain_exactly(
        :name, :description, :default_servings, :prep_time_minutes, :cook_time_minutes,
        :total_time_minutes, :difficulty, :diet, :appliance, :instructions,
        :suggested_tags, :ingredients
      )
      expect(schema[:required]).to match_array(schema[:properties].keys.map(&:to_s))
      expect(schema[:additionalProperties]).to be(false)
      expect(ingredient_schema[:properties].keys).to contain_exactly(:name, :quantity, :unit)
    end

    # Une valeur hors enum serait silencieusement effacée à la création du
    # brouillon (RecipeImportsController#valid_enum) : le schéma doit donc
    # énumérer exactement ce que Recipe accepte, ni plus ni moins.
    it "n'autorise que les valeurs des enums de Recipe" do
      expect(nullable_enum_of(schema[:properties][:difficulty])).to eq(Recipe.difficulties.keys)
      expect(schema[:properties][:diet][:enum]).to eq(Recipe.diets.keys)
    end

    it "n'autorise que les unités connues du panneau d'ingrédients" do
      expect(nullable_enum_of(ingredient_schema[:properties][:unit]))
        .to eq(described_class::INGREDIENT_UNITS)
    end

    def ingredient_schema
      schema[:properties][:ingredients][:items]
    end

    # Un champ facultatif se déclare « anyOf [type, null] » : l'enum est porté
    # par la branche typée.
    def nullable_enum_of(property)
      expect(property[:anyOf].last).to eq(type: "null")
      property[:anyOf].first[:enum]
    end
  end
end
