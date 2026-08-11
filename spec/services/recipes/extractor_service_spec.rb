# frozen_string_literal: true

require "rails_helper"
require_relative "../../support/recipe_page_fixtures"

# Spec de Recipes::ExtractorService, né comme filet de sécurité avant le
# découpage du service : si un exemple rougit après un refactoring, c'est que le
# comportement a bougé.
#
# Le service ne fait plus que de l'orchestration : le HTTP vers les sites
# (PageFetcher), la lecture des pages (SchemaOrgParser), l'écriture des prompts
# (ClaudePrompts) et l'appel à l'API (ClaudeClient) ont chacun leur classe et
# leur spec. Ces collaborateurs sont donc simulés ici, et les exemples vérifient
# qui est appelé, avec quoi, et ce qu'on fait de la réponse.
#
# Écrits d'abord en tests de caractérisation, ces exemples ont mis au jour six
# bugs, tous corrigés depuis ; le seul qui touche encore à l'orchestration garde
# ici un exemple de non-régression marqué « RÉGRESSION » (les autres ont suivi
# leur méthode dans schema_org_parser_spec.rb et claude_client_spec.rb) :
#   6. le repli « chaînes brutes » de la structuration des ingrédients était
#      inatteignable, son `rescue ExtractionError` ne pouvant pas s'armer tant
#      que l'appel à l'IA levait un NameError (RÉGRESSION n°5).
RSpec.describe Recipes::ExtractorService do
  include RecipePageFixtures

  let(:url) { "https://exemple.fr/recette" }

  # Messages soumis à l'IA, un tableau par appel : ClaudeClient étant simulé,
  # c'est ainsi qu'on inspecte ce que le service lui a confié.
  let(:claude_calls) { [] }

  # IA scellée par défaut : tout appel non explicitement simulé par l'exemple
  # lève une erreur bruyante.
  before do
    allow(Recipes::ClaudeClient).to receive(:call) do
      raise "Appel à l'IA non simulé dans cet exemple"
    end
  end

  # ── Simulation des collaborateurs ───────────────────────────────────────

  # La récupération de la page relève de PageFetcher, testé pour lui-même :
  # ici on lui substitue la page voulue. Le `with(url)` vérifie au passage que
  # le service lui transmet bien l'URL reçue.
  def stub_page(html)
    allow(Recipes::PageFetcher).to receive(:call).with(url).and_return(html)
  end

  # @param answer [Object] ce que l'IA retourne (déjà analysé par ClaudeClient)
  def stub_claude(answer)
    allow(Recipes::ClaudeClient).to receive(:call) do |messages|
      claude_calls << messages
      answer
    end
  end

  # Panne de l'IA : ClaudeClient traduit toutes les siennes en ExtractionError.
  def stub_claude_failure(message = "Erreur API Claude (529) : overloaded_error")
    allow(Recipes::ClaudeClient).to receive(:call) do |messages|
      claude_calls << messages
      raise Recipes::ExtractionError, message
    end
  end

  # Recette telle que le service la reconstruit depuis schema_recipe.
  let(:extracted_recipe) do
    {
      "name"               => "Tarte aux poireaux",
      "description"        => "Une tarte salée de saison",
      "default_servings"   => 6,
      "prep_time_minutes"  => 20,
      "cook_time_minutes"  => 40,
      "total_time_minutes" => 60,
      "difficulty"         => nil,
      "diet"               => "omnivore",
      "appliance"          => nil,
      "instructions"       => "1. Préchauffer le four.\n2. Enfourner 40 minutes.",
      "suggested_tags"     => [ "Plat principal", "Tarte" ],
      "ingredients"        => []
    }
  end

  # ── from_url : chemin schema.org ────────────────────────────────────────

  describe ".from_url avec du schema.org" do
    it "reconstruit toute la recette depuis le schema.org, sans solliciter l'IA" do
      stub_page(page_with_json_ld(schema_recipe))

      expect(described_class.from_url(url)).to eq(extracted_recipe)
      expect(claude_calls).to be_empty
    end

    it "confie les ingrédients bruts à l'IA et retourne sa structuration" do
      schema     = schema_recipe.merge("recipeIngredient" => [ "200 g de farine", "", "3 oeufs" ])
      structured = [
        { "name" => "farine", "quantity" => 200, "unit" => "g" },
        { "name" => "oeufs", "quantity" => 3, "unit" => nil }
      ]
      stub_page(page_with_json_ld(schema))
      stub_claude(structured)

      expect(described_class.from_url(url)["ingredients"]).to eq(structured)
      # Les ingrédients vides sont retirés avant d'être soumis à l'IA.
      expect(claude_calls.last)
        .to eq(Recipes::ClaudePrompts.ingredients_messages([ "200 g de farine", "3 oeufs" ]))
    end
  end

  # ── from_url : repli sur l'extraction IA du texte ───────────────────────

  describe ".from_url sans schema.org" do
    let(:ia_result) { { "name" => "Soupe de potiron", "ingredients" => [] } }

    before { stub_page(page_without_json_ld) }

    it "soumet à l'IA le texte nettoyé de la page" do
      stub_claude(ia_result)

      expect(described_class.from_url(url)).to eq(ia_result)

      prompt = claude_calls.last.first[:content]
      expect(prompt).to include("Soupe de potiron", "Faire revenir le potiron.")
      # C'est le texte extrait qui part dans le prompt, pas le HTML brut.
      expect(prompt).not_to include("analytics", "Accueil Recettes", "Mentions legales")
    end

    # Contrairement aux ingrédients, la recette entière n'a pas de repli : sans
    # l'IA il n'y a rien à importer, et l'erreur doit atteindre le contrôleur.
    it "laisse remonter l'échec de l'IA" do
      stub_claude_failure

      expect { described_class.from_url(url) }
        .to raise_error(Recipes::ExtractionError, "Erreur API Claude (529) : overloaded_error")
    end
  end

  # ── from_photo ──────────────────────────────────────────────────────────

  describe ".from_photo" do
    let(:ia_result) { { "name" => "Gratin de courgettes", "ingredients" => [] } }

    before { stub_claude(ia_result) }

    it "confie la photo à l'IA avec son media_type et retourne la recette extraite" do
      expect(described_class.from_photo("QUJD", media_type: "image/png")).to eq(ia_result)
      expect(claude_calls.last).to eq(Recipes::ClaudePrompts.photo_messages("QUJD", "image/png"))
    end

    it "utilise le media_type image/jpeg par défaut" do
      described_class.from_photo("QUJD")

      expect(claude_calls.last).to eq(Recipes::ClaudePrompts.photo_messages("QUJD", "image/jpeg"))
    end
  end

  # ── Structuration des ingrédients : le repli ────────────────────────────

  describe "repli sur les ingrédients bruts" do
    let(:raw_ingredients) { [ "200 g de farine", "3 oeufs" ] }
    let(:raw_fallback) do
      [
        { "name" => "200 g de farine", "quantity" => nil, "unit" => nil },
        { "name" => "3 oeufs", "quantity" => nil, "unit" => nil }
      ]
    end

    before { stub_page(page_with_json_ld(schema_recipe.merge("recipeIngredient" => raw_ingredients))) }

    # RÉGRESSION n°6 — ce repli était du code mort : son `rescue
    # ExtractionError` ne pouvait pas s'armer, l'appel à l'IA levant un
    # NameError (RÉGRESSION n°5) avant toute conversion en ExtractionError. Un
    # échec de l'IA doit dégrader l'import, jamais l'interrompre.
    it "garde les chaînes brutes quand l'IA échoue" do
      stub_claude_failure

      expect(described_class.from_url(url)["ingredients"]).to eq(raw_fallback)
    end

    it "garde les chaînes brutes quand l'IA répond autre chose qu'un tableau" do
      stub_claude("ingredients" => [])

      expect(described_class.from_url(url)["ingredients"]).to eq(raw_fallback)
    end
  end
end
