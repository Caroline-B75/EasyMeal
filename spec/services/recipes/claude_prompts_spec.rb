# frozen_string_literal: true

require "rails_helper"

# Spec de Recipes::ClaudePrompts. Aucun réseau ici : ces exemples ne lisent que
# ce qu'on s'apprête à demander à l'IA — les messages et le schéma de sortie.
#
# Ils verrouillent deux mutualisations : les règles envoyées au texte comme à la
# photo (recopiées, une correction d'un seul côté faisait silencieusement
# diverger l'import URL de l'import photo), et le vocabulaire du classement, qui
# n'est jamais recopié ici mais lu sur MealTypes, sur les enums de Recipe et sur
# les tags en base — l'IA ne peut ainsi proposer que ce que le formulaire de
# validation accepterait.
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

    # Extraire et classer sont deux gestes opposés : l'un ne doit rien inventer,
    # l'autre doit justement trancher. Les mélanger fait retomber le classement
    # sur « la source ne le dit pas, donc je ne remplis pas ».
    it "sépare les règles d'extraction des règles de classement" do
      expect(message[:content]).to include(
        "Règles d'extraction — ne jamais inventer d'information absente du texte",
        "Règles de classement — ici il faut juger, même quand la source ne le dit pas"
      )
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
      expect(content.last[:text]).to include("ne jamais inventer d'information absente de la photo")
    end
  end

  describe ".schema_org_request" do
    subject(:request) do
      described_class.schema_org_request(
        name:         "Quiche lorraine",
        description:  "La vraie, celle sans fromage.",
        categories:   [ "Plat principal" ],
        instructions: "1. Préchauffer le four.",
        ingredients:  [ "200 g de farine", "3 oeufs" ]
      )
    end

    it "liste les ingrédients à structurer, un par ligne" do
      expect(request[:messages].first[:content]).to include("Ingrédients :\n- 200 g de farine\n- 3 oeufs")
    end

    # Un seul appel pour les deux manques de la page : sans ce que le site dit
    # déjà de la recette, l'IA n'aurait pas de quoi la classer.
    it "joint aux ingrédients ce que le site dit déjà de la recette" do
      expect(request[:messages].first[:content]).to include(
        "Recette : Quiche lorraine",
        "Description : La vraie, celle sans fromage.",
        "Catégories annoncées par le site : Plat principal",
        "Étapes : 1. Préchauffer le four."
      )
    end

    # La racine d'un schéma est forcément un objet : le tableau attendu voyage
    # donc sous une clé, qu'ExtractorService déballe.
    it "attend le tableau structuré sous la clé « ingredients », avec le classement" do
      expect(request[:schema][:properties].keys)
        .to contain_exactly(:ingredients, :difficulty, :diet, :price, :meal_types)
      expect(request[:schema][:properties][:ingredients][:type]).to eq("array")
    end

    # Sans ingrédients, il reste le classement à demander — mais rien à
    # structurer, et surtout rien à inventer.
    it "dit franchement quand le site ne liste aucun ingrédient" do
      request = described_class.schema_org_request(
        name: "Quiche", description: nil, categories: [], instructions: nil, ingredients: []
      )

      expect(request[:messages].first[:content])
        .to include("Le site ne liste aucun ingrédient : rends un tableau ingredients vide.")
      expect(request[:messages].first[:content]).not_to include("Description :")
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

    # Le modèle rendait « 3 càc » d'une recette qui disait « 3 c. à s. » : la
    # règle doit nommer les abréviations, et les nommer avec les jetons que le
    # schéma attend — sans quoi renommer un jeton laisserait le prompt en parler
    # dans une langue que l'IA n'a plus le droit d'employer.
    it "nomme les abréviations des cuillères, avec les jetons du schéma" do
      spoons = Units::AI_UNITS.grep(/cuillere/)

      expect(spoons.size).to eq(2)
      expect(described_class::UNIT_RULE).to include(*spoons, "c. à s.", "c. à c.")
    end

    it "impose exactement le même schéma de sortie" do
      expect(described_class.photo_request("QUJD", "image/jpeg")[:schema])
        .to eq(described_class.text_request("Une recette")[:schema])
    end
  end

  # ── Règles de classement ────────────────────────────────────────────────

  describe "règles de classement" do
    subject(:prompt) { described_class.text_request("Une recette")[:messages].first[:content] }

    # La hiérarchie DIET_COMPATIBILITY en dépend pour la génération de menus :
    # une recette végétarienne classée « omnivore » sort des menus végétariens.
    it "demande le régime le plus restrictif réellement applicable" do
      expect(prompt).to include("le régime le PLUS restrictif qui s'applique réellement")
    end

    # Les moments sont des clés anglaises : sans leurs libellés, « snack » et
    # « apero » se confondent.
    it "présente les moments du repas avec leurs libellés français" do
      expect(prompt).to include(
        "Moments possibles : " +
        MealTypes::MEAL_TYPES.map { |type| "#{type} (#{MealTypes.label(type)})" }.join(", ")
      )
    end

    it "n'ouvre le catalogue de tags que lorsqu'il y en a" do
      expect(prompt).not_to include("à choisir dans ce catalogue")

      create(:tag, name: "rapide", tag_type: :rapidite)

      expect(described_class.text_request("Une recette")[:messages].first[:content]).to include(
        "de 0 à #{described_class::MAX_TAGS} tags",
        "Rapidité : rapide"
      )
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
        :total_time_minutes, :appliance, :instructions, :ingredients,
        :difficulty, :diet, :price, :meal_types
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
      expect(nullable_enum_of(schema[:properties][:price])).to eq(Recipe.prices.keys)
    end

    # Le vocabulaire des moments vit dans MealTypes, et lui seul.
    it "n'autorise que les moments du repas connus" do
      expect(schema[:properties][:meal_types][:items][:enum]).to eq(MealTypes::MEAL_TYPES)
    end

    # L'IA ne peut littéralement pas suggérer un tag qui n'existe pas : aucun
    # rapprochement approximatif à faire côté Ruby, aucun tag à créer.
    it "n'autorise que les tags du catalogue, et ne réclame rien quand il est vide" do
      expect(schema[:properties]).not_to have_key(:tags)

      create(:tag, name: "rapide")
      create(:tag, name: "de saison")

      tags = described_class.text_request("Une recette")[:schema][:properties][:tags]
      expect(tags[:items][:enum]).to eq([ "de saison", "rapide" ])
    end

    # Le vocabulaire des unités vit dans Units, et lui seul.
    it "n'autorise que les unités du vocabulaire imposé à l'IA" do
      expect(nullable_enum_of(ingredient_schema[:properties][:unit])).to eq(Units::AI_UNITS)
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
