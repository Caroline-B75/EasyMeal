# frozen_string_literal: true

require "rails_helper"

# Vocabulaire des unités de mesure : les façons de les écrire, ce qu'elles
# valent, et la cohérence des trois tables entre elles.
RSpec.describe Units do
  describe ".canonical" do
    it "reconnaît une unité déjà canonique" do
      expect(described_class.canonical("g")).to eq("g")
    end

    it "ignore la casse et les espaces" do
      expect(described_class.canonical(" L ")).to eq("l")
    end

    # Le cas qui a motivé la table : une même cuillère à soupe s'écrit de dix
    # façons dans les recettes, et l'accent seul distinguait « càs » de « càc ».
    it "ramène toutes les écritures de la cuillère à soupe à une seule unité" do
      [ "càs", "cas", "c. à s.", "c à s", "CS", "cuil. à soupe", "cuillères à soupe",
        "cuillere_a_soupe", "tbsp" ].each do |written|
        expect(described_class.canonical(written)).to eq("cas"), "échoue sur #{written.inspect}"
      end
    end

    it "en fait autant pour la cuillère à café, dite aussi à thé" do
      [ "càc", "cac", "c. à c.", "cc", "cuil. à café", "cuillères à thé",
        "cuillere_a_cafe", "tsp" ].each do |written|
        expect(described_class.canonical(written)).to eq("cac"), "échoue sur #{written.inspect}"
      end
    end

    # « tranches » ou « brins » ne sont pas des unités de mesure : les accepter
    # ferait passer une quantité pour convertie alors qu'elle est à corriger.
    it "renonce sur ce qui n'est pas une unité, comme sur une unité absente" do
      expect(described_class.canonical("tranches")).to be_nil
      expect(described_class.canonical(nil)).to be_nil
      expect(described_class.canonical("")).to be_nil
    end
  end

  describe ".definition" do
    it "donne le groupe et le facteur vers l'unité de base" do
      expect(described_class.definition("cuillere_a_soupe")).to eq(unit_group: "spoon", factor: 3.0)
    end

    # Une recette ne dit jamais « 3 pièces d'oeufs » : l'IA laisse l'unité vide.
    it "compte en pièces ce qui n'a pas d'unité" do
      expect(described_class.definition(nil)).to eq(unit_group: "count", factor: 1.0)
    end

    it "ne définit rien pour une unité illisible" do
      expect(described_class.definition("tranches")).to be_nil
    end
  end

  describe ".label" do
    it "rend l'unité lisible en français, quelle que soit son écriture" do
      expect(described_class.label("cas")).to eq("càs")
      expect(described_class.label("c. à c.")).to eq("càc")
      expect(described_class.label("piece")).to eq("pièce")
      expect(described_class.label("l")).to eq("L")
      expect(described_class.label("g")).to eq("g")
    end

    # Mieux vaut afficher « 2 tranches » que de faire disparaître ce que la
    # recette disait.
    it "laisse une unité illisible s'écrire telle quelle" do
      expect(described_class.label("tranches")).to eq("tranches")
    end
  end

  describe ".factor_to" do
    it "ramène une unité à l'unité de base de son propre groupe" do
      expect(described_class.factor_to("cl", :volume)).to eq(10.0)
      expect(described_class.factor_to("kg", :mass)).to eq(1000.0)
    end

    # Le cas de l'huile d'olive : la recette dit « 2 càs », le catalogue compte
    # en millilitres. Une cuillère à soupe fait 15 ml quoi qu'on y mette.
    it "traverse d'un groupe à l'autre quand l'équivalence est universelle" do
      expect(described_class.factor_to("cas", :volume)).to eq(15.0)
      expect(described_class.factor_to("cac", :volume)).to eq(5.0)
      expect(described_class.factor_to("cl", :spoon)).to eq(2.0)
    end

    # Une cuillère de farine et une cuillère de miel ne pèsent pas le même
    # poids : le passage au poids n'a rien d'universel et n'appartient pas à Units.
    it "renonce à traverser vers un poids" do
      expect(described_class.factor_to("cas", :mass)).to be_nil
      expect(described_class.factor_to("g", :volume)).to be_nil
    end

    it "renonce sur une unité illisible" do
      expect(described_class.factor_to("tranches", :mass)).to be_nil
    end
  end

  describe ".select_options" do
    # Une huile se dose aussi bien au millilitre qu'à la cuillère : les unités du
    # groupe d'abord, dans l'ordre croissant, puis les cuillères — c'est cet
    # ordre que le sélecteur du formulaire suit.
    it "propose les cuillères aux ingrédients comptés en volume" do
      expect(described_class.select_options(:volume))
        .to eq([ [ "ml", "ml" ], [ "cl", "cl" ], [ "dl", "dl" ], [ "L", "l" ],
                 [ "càc", "cac" ], [ "càs", "cas" ] ])
    end

    # Le sens inverse n'est pas proposé : les ingrédients comptés en cuillères
    # sont pour l'essentiel des épices et des poudres, et « 20 cl de curcuma »
    # n'inviterait qu'à se tromper. La conversion, elle, sait toujours le lire
    # (cf. .factor_to).
    it "ne propose pas de volume à ce qui se compte en cuillères" do
      expect(described_class.select_options("spoon")).to eq([ [ "càc", "cac" ], [ "càs", "cas" ] ])
    end

    it "s'en tient au groupe quand rien ne s'y ramène" do
      expect(described_class.select_options(:mass)).to eq([ [ "g", "g" ], [ "kg", "kg" ] ])
      expect(described_class.select_options(:count)).to eq([ [ "pièce", "piece" ] ])
    end

    it "ne propose rien pour un groupe inconnu" do
      expect(described_class.select_options(nil)).to eq([])
    end
  end

  # Lire et proposer sont deux gestes distincts : cette asymétrie est le cœur du
  # sens unique, et le sélecteur du formulaire comme le panneau IA s'y règlent.
  describe ".offered?" do
    it "offre la cuillère au volume, jamais l'inverse" do
      expect(described_class.offered?("spoon", "volume")).to be(true)
      expect(described_class.offered?("volume", "spoon")).to be(false)
    end

    it "n'offre rien entre deux groupes qu'aucune équivalence ne relie" do
      expect(described_class.offered?("spoon", "mass")).to be(false)
    end
  end

  describe ".table" do
    it "rend chaque unité avec son groupe, son facteur et son libellé" do
      expect(described_class.table[:units]["cas"]).to eq(unit_group: "spoon", factor: 3.0, label: "càs")
    end

    # Sans les équivalences, le JS ne saurait pas composer les facteurs ; sans
    # leur `offered`, il proposerait des centilitres de curcuma.
    it "emporte les équivalences avec les unités" do
      expect(described_class.table[:equivalences]).to eq(
        "spoon>volume" => { factor: 5.0, offered: true },
        "volume>spoon" => { factor: 0.2, offered: false }
      )
    end
  end

  # Ces trois exemples gardent la cohérence des tables : elles se répondent, et
  # une entrée ajoutée d'un côté sans l'autre casserait silencieusement soit la
  # conversion, soit le dialogue avec l'IA.
  describe "cohérence des tables" do
    it "n'expose que des alias déjà normalisés, vers des unités connues" do
      described_class::ALIASES.each do |written, unit|
        expect(described_class.normalize(written)).to eq(written)
        expect(described_class::UNITS).to have_key(unit)
      end
    end

    it "impose à l'IA un vocabulaire que Ruby sait relire" do
      described_class::AI_UNITS.each do |ai_unit|
        expect(described_class.canonical(ai_unit)).to be_present, "l'IA peut répondre #{ai_unit.inspect}, illisible ici"
      end
    end

    it "donne une unité de base à chaque groupe d'unités d'ingrédient" do
      expect(described_class::BASE_UNITS.keys).to match_array(Ingredient.unit_groups.keys)
    end
  end
end
