# frozen_string_literal: true

require "rails_helper"
require_relative "../../support/recipe_page_fixtures"

# Spec de Recipes::SchemaOrgParser, extrait d'ExtractorService : ces exemples
# étaient auparavant écrits contre des méthodes privées atteintes par `send`.
# Les méthodes étant maintenant publiques sur une classe autonome, ils les
# appellent normalement — aucun `send` ne subsiste ici.
#
# Quatre des six bugs mis au jour par les tests de caractérisation vivaient dans
# ces méthodes ; chacun garde ici un exemple de non-régression marqué
# « RÉGRESSION ».
RSpec.describe Recipes::SchemaOrgParser do
  include RecipePageFixtures

  # ── parse_schema_org ────────────────────────────────────────────────────

  describe ".parse_schema_org" do
    # RÉGRESSION n°4 — Array(Hash) éclatait l'objet en paires clé/valeur, dont
    # aucune n'est un Hash : la forme la plus courante du schema.org était
    # ignorée et chaque import repartait inutilement vers l'IA.
    it "trouve un objet Recipe nu" do
      expect(described_class.parse_schema_org(page_with_json_ld(schema_recipe))).to eq(schema_recipe)
    end

    it "trouve la recette dans un tableau JSON-LD racine" do
      page = page_with_json_ld([ { "@type" => "WebPage" }, schema_recipe ])

      expect(described_class.parse_schema_org(page)).to eq(schema_recipe)
    end

    it "trouve la recette encapsulée dans un @graph" do
      expect(described_class.parse_schema_org(page_with_graph(schema_recipe))).to eq(schema_recipe)
    end

    it "retient le premier bloc exploitable quand la page en porte plusieurs" do
      page = page_with_json_ld({ "@type" => "WebPage" }, schema_recipe)

      expect(described_class.parse_schema_org(page)).to eq(schema_recipe)
    end

    # RÉGRESSION n°5 — le `rescue JSON::ParseError` visait une constante
    # inexistante : le rescue lui-même levait un NameError, jamais rattrapé par
    # RecipeImportsController, donc une erreur 500 sur toute page portant un
    # bloc JSON-LD malformé (elles sont nombreuses).
    it "ignore un bloc JSON-LD malformé et exploite le suivant" do
      page = page_with_json_ld("{ ceci n'est pas du JSON", schema_recipe)

      expect(described_class.parse_schema_org(page)).to eq(schema_recipe)
    end

    it "retourne nil quand le seul bloc JSON-LD est malformé" do
      expect(described_class.parse_schema_org(page_with_json_ld("{ ceci n'est pas du JSON"))).to be_nil
    end

    it "retourne nil quand le JSON-LD n'est pas un objet" do
      expect(described_class.parse_schema_org(page_with_json_ld('"un simple texte"'))).to be_nil
    end

    it "retourne nil quand aucun nœud n'est une recette" do
      page = page_with_json_ld({ "@graph" => [ { "@type" => "WebPage" }, { "@type" => "Article" } ] })

      expect(described_class.parse_schema_org(page)).to be_nil
    end

    it "retourne nil quand la page ne porte aucun JSON-LD" do
      expect(described_class.parse_schema_org(page_without_json_ld)).to be_nil
    end
  end

  # ── recipe_type? ────────────────────────────────────────────────────────

  describe ".recipe_type?" do
    it "reconnaît un @type string" do
      expect(described_class.recipe_type?({ "@type" => "Recipe" })).to be(true)
    end

    it "reconnaît un @type tableau contenant Recipe" do
      expect(described_class.recipe_type?({ "@type" => [ "Recipe", "NewsArticle" ] })).to be(true)
    end

    it "rejette un @type qui n'est pas une recette" do
      expect(described_class.recipe_type?({ "@type" => "WebPage" })).to be(false)
      expect(described_class.recipe_type?({ "@type" => nil })).to be(false)
      expect(described_class.recipe_type?({})).to be(false)
    end

    # RÉGRESSION n°3 — la comparaison était stricte, et tous les sites qui
    # déclarent leur type par son URL de vocabulaire étaient ignorés.
    it "reconnaît un @type exprimé en URL schema.org complète" do
      expect(described_class.recipe_type?({ "@type" => "http://schema.org/Recipe" })).to be(true)
      expect(described_class.recipe_type?({ "@type" => "https://schema.org/Recipe" })).to be(true)
    end

    it "rejette toute donnée qui n'est pas un Hash" do
      expect(described_class.recipe_type?("Recipe")).to be(false)
      expect(described_class.recipe_type?([ "Recipe" ])).to be(false)
      expect(described_class.recipe_type?(nil)).to be(false)
    end
  end

  # ── parse_yield ─────────────────────────────────────────────────────────

  describe ".parse_yield" do
    it "extrait le nombre de parts d'un libellé" do
      expect(described_class.parse_yield("4 personnes")).to eq(4)
      expect(described_class.parse_yield("Pour 12 mini-cakes")).to eq(12)
    end

    it "retient le dernier nombre d'un intervalle (la borne haute)" do
      expect(described_class.parse_yield("4-6 parts")).to eq(6)
    end

    it "accepte une valeur déjà numérique" do
      expect(described_class.parse_yield(4)).to eq(4)
    end

    it "retourne nil quand aucun chiffre n'est présent" do
      expect(described_class.parse_yield("quelques parts")).to be_nil
    end

    it "retourne nil sur une valeur vide" do
      expect(described_class.parse_yield(nil)).to be_nil
      expect(described_class.parse_yield("")).to be_nil
    end
  end

  # ── parse_iso_duration ──────────────────────────────────────────────────

  describe ".parse_iso_duration" do
    # RÉGRESSION n°1 — la regex a longtemps été entièrement optionnelle : elle
    # matchait la chaîne VIDE dès le préfixe "PT" sans jamais atteindre les
    # chiffres, et aucune durée n'était importée.
    it "convertit les durées ISO 8601 en minutes" do
      expect(described_class.parse_iso_duration("PT1H30M")).to eq(90)
      expect(described_class.parse_iso_duration("PT45M")).to eq(45)
      expect(described_class.parse_iso_duration("PT2H")).to eq(120)
    end

    it "lit aussi la forme longue, partie calendaire comprise" do
      expect(described_class.parse_iso_duration("P0DT1H30M")).to eq(90)
    end

    it "retourne nil sur une valeur vide ou non parsable" do
      expect(described_class.parse_iso_duration(nil)).to be_nil
      expect(described_class.parse_iso_duration("")).to be_nil
      expect(described_class.parse_iso_duration("une bonne heure")).to be_nil
      expect(described_class.parse_iso_duration("PT0M")).to be_nil
    end
  end

  # ── format_instructions ─────────────────────────────────────────────────

  describe ".format_instructions" do
    it "numérote un tableau de Hash en lisant text puis name" do
      steps = [ { "text" => "Préchauffer." }, { "name" => "Enfourner." } ]

      expect(described_class.format_instructions(steps)).to eq("1. Préchauffer.\n2. Enfourner.")
    end

    it "numérote un tableau de String" do
      expect(described_class.format_instructions([ "Préchauffer.", "Enfourner." ]))
        .to eq("1. Préchauffer.\n2. Enfourner.")
    end

    it "accepte un mélange de Hash et de String et renumérote après filtrage des vides" do
      steps = [ "Préchauffer.", "", { "text" => "   " }, { "text" => "Enfourner." } ]

      expect(described_class.format_instructions(steps)).to eq("1. Préchauffer.\n2. Enfourner.")
    end

    it "retourne une chaîne vide sur une donnée vide" do
      expect(described_class.format_instructions(nil)).to eq("")
      expect(described_class.format_instructions([])).to eq("")
      expect(described_class.format_instructions("")).to eq("")
    end

    # RÉGRESSION n°2 — avec Array(), un Hash unique était éclaté en paires
    # clé/valeur qui ne matchaient ni Hash ni String, et l'étape était perdue.
    it "accepte une étape unique fournie hors tableau" do
      expect(described_class.format_instructions({ "text" => "Tout mélanger." })).to eq("1. Tout mélanger.")
      expect(described_class.format_instructions("Tout mélanger.")).to eq("1. Tout mélanger.")
    end
  end

  # ── parse_categories ────────────────────────────────────────────────────

  describe ".parse_categories" do
    it "découpe une liste séparée par des virgules ou des barres obliques" do
      expect(described_class.parse_categories("Plat principal, Tarte")).to eq([ "Plat principal", "Tarte" ])
      expect(described_class.parse_categories("Entrée/Apéritif")).to eq([ "Entrée", "Apéritif" ])
    end

    it "accepte un tableau et écarte les entrées vides" do
      expect(described_class.parse_categories([ "Dessert", "", "Gâteau, Tarte" ]))
        .to eq([ "Dessert", "Gâteau", "Tarte" ])
    end

    it "retourne un tableau vide sur une valeur absente" do
      expect(described_class.parse_categories(nil)).to eq([])
      expect(described_class.parse_categories("")).to eq([])
    end
  end

  # ── extract_text ────────────────────────────────────────────────────────

  describe ".extract_text" do
    it "retient le contenu de la recette et retire l'habillage de la page" do
      text = described_class.extract_text(page_without_json_ld)

      expect(text).to include("Soupe de potiron", "Faire revenir le potiron.")
      # script, style, nav et footer n'apprennent rien sur la recette.
      expect(text).not_to include("analytics", "color: red", "Accueil Recettes", "Mentions legales")
    end

    it "réduit les espaces répétés et les lignes vides en trop" do
      html = "<p>Deux    espaces</p>\n\n\n\n\n<p>et cinq sauts de ligne</p>"

      expect(described_class.extract_text(html)).to eq("Deux espaces\n\net cinq sauts de ligne")
    end

    # Le texte part dans un prompt : au-delà de cette longueur, on paie des
    # tokens pour du contenu qui n'est plus la recette.
    it "tronque le texte à la longueur maximale soumise à l'IA" do
      html = "<p>#{'a' * (described_class::MAX_TEXT_CHARS + 100)}</p>"

      expect(described_class.extract_text(html).length).to eq(described_class::MAX_TEXT_CHARS)
    end
  end
end
