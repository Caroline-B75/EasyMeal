# frozen_string_literal: true

require "rails_helper"

RSpec.describe UnitConversionService do
  # Les ingrédients ne sont jamais sauvegardés ici : la conversion ne lit que
  # leur unité et leur poids unitaire.
  def ingredient(unit_group, base_unit, piece_weight_g: nil, density: nil, density_source: :manual)
    build(:ingredient, unit_group: unit_group, base_unit: base_unit, piece_weight_g: piece_weight_g,
                       density_g_per_ml: density, density_source: density && density_source)
  end

  describe ".convert" do
    context "au sein d'un même groupe d'unités" do
      it "ramène une masse à des grammes" do
        expect(described_class.convert(quantity: 1.5, from_unit: "kg", ingredient: ingredient(:mass, "g")))
          .to eq(1500.0)
      end

      it "ramène un volume à des millilitres" do
        expect(described_class.convert(quantity: 20, from_unit: "cl", ingredient: ingredient(:volume, "ml")))
          .to eq(200.0)
      end

      it "ramène une cuillère à soupe à des cuillères à café" do
        expect(described_class.convert(quantity: 2, from_unit: "càs", ingredient: ingredient(:spoon, "cac")))
          .to eq(6.0)
      end

      # L'IA laisse l'unité vide pour ce qui se compte (« 3 oeufs »)
      it "traite l'absence d'unité comme un décompte" do
        expect(described_class.convert(quantity: 3, from_unit: nil, ingredient: ingredient(:count, "piece")))
          .to eq(3.0)
      end

      it "accepte une unité écrite en majuscules ou entourée d'espaces" do
        expect(described_class.convert(quantity: 1, from_unit: " L ", ingredient: ingredient(:volume, "ml")))
          .to eq(1000.0)
      end

      # Les écritures possibles d'une unité sont l'affaire de Units : ce qui
      # compte ici, c'est qu'aucune ne se perde en route (une recette qui dit
      # « 3 c. à s. » ne doit pas devenir 3 càc).
      it "accepte les écritures que Units sait lire" do
        huile = ingredient(:spoon, "cac")

        expect(described_class.convert(quantity: 3, from_unit: "c. à s.", ingredient: huile)).to eq(9.0)
        expect(described_class.convert(quantity: 3, from_unit: "cuillere_a_soupe", ingredient: huile)).to eq(9.0)
        expect(described_class.convert(quantity: 3, from_unit: "cuillères à café", ingredient: huile)).to eq(3.0)
      end
    end

    # Une cuillère est une mesure de volume : le catalogue compte l'huile en
    # millilitres, les recettes en cuillères, et les deux se rejoignent sans
    # rien savoir de l'ingrédient.
    context "entre cuillères et volume" do
      it "ramène des cuillères à soupe à des millilitres" do
        expect(described_class.convert(quantity: 2, from_unit: "càs", ingredient: ingredient(:volume, "ml")))
          .to eq(30.0)
      end

      it "ramène aussi un volume à des cuillères à café" do
        expect(described_class.convert(quantity: 10, from_unit: "cl", ingredient: ingredient(:spoon, "cac")))
          .to eq(20.0)
      end
    end

    context "d'un groupe à l'autre, par le poids unitaire" do
      # Le cas d'origine : la recette compte des tranches, le catalogue pèse.
      it "convertit un décompte en masse" do
        jambon = ingredient(:mass, "g", piece_weight_g: 40)

        expect(described_class.convert(quantity: 2, from_unit: nil, ingredient: jambon)).to eq(80.0)
      end

      it "convertit une masse en décompte" do
        oeuf = ingredient(:count, "piece", piece_weight_g: 50)

        expect(described_class.convert(quantity: 200, from_unit: "g", ingredient: oeuf)).to eq(4.0)
      end

      # La quantité rejoint d'abord l'unité de base de son propre groupe (kg → g)
      # avant de traverser : sans cela, 1 kg vaudrait 1 pièce.
      it "traverse depuis une unité dérivée" do
        oeuf = ingredient(:count, "piece", piece_weight_g: 50)

        expect(described_class.convert(quantity: 1, from_unit: "kg", ingredient: oeuf)).to eq(20.0)
      end

      it "renonce quand l'ingrédient n'a pas de poids unitaire" do
        expect(described_class.convert(quantity: 2, from_unit: nil, ingredient: ingredient(:mass, "g")))
          .to be_nil
      end
    end

    # Le second pont porté par l'ingrédient : une cuillère à soupe fait 15 ml
    # partout, mais ces 15 ml ne pèsent le même poids pour personne.
    context "d'une mesure à un poids, par la densité" do
      it "pèse une cuillerée de farine" do
        farine = ingredient(:mass, "g", density: 0.55)

        expect(described_class.convert(quantity: 1, from_unit: "càs", ingredient: farine)).to eq(8.25)
      end

      it "pèse aussi un volume" do
        farine = ingredient(:mass, "g", density: 0.55)

        expect(described_class.convert(quantity: 10, from_unit: "cl", ingredient: farine)).to eq(55.0)
      end

      # L'autre sens : la recette pèse, le catalogue compte en cuillères.
      it "convertit un poids en cuillères" do
        miel = ingredient(:spoon, "cac", density: 1.42)

        expect(described_class.convert(quantity: 200, from_unit: "g", ingredient: miel)).to eq(28.169)
      end

      it "convertit un poids en millilitres" do
        huile = ingredient(:volume, "ml", density: 0.91)

        expect(described_class.convert(quantity: 200, from_unit: "g", ingredient: huile)).to eq(219.78)
      end

      it "renonce quand l'ingrédient n'a pas de densité" do
        expect(described_class.convert(quantity: 1, from_unit: "càs", ingredient: ingredient(:mass, "g")))
          .to be_nil
      end
    end

    context "quand aucune conversion n'existe" do
      # Il faudrait la densité de l'ingrédient : une cuillère de farine et une
      # cuillère de miel ne pèsent pas le même poids.
      it "renonce entre des cuillères et une masse" do
        expect(described_class.convert(quantity: 2, from_unit: "càs", ingredient: ingredient(:mass, "g")))
          .to be_nil
      end

      # Le poids unitaire ne relie que masse et décompte : un volume reste hors
      # d'atteinte même quand il est renseigné.
      it "renonce entre un décompte et un volume, même avec un poids unitaire" do
        lait = ingredient(:volume, "ml", piece_weight_g: 1000)

        expect(described_class.convert(quantity: 1, from_unit: nil, ingredient: lait)).to be_nil
      end

      it "renonce sur une unité inconnue de la table" do
        expect(described_class.convert(quantity: 2, from_unit: "tranches", ingredient: ingredient(:mass, "g")))
          .to be_nil
      end
    end
  end

  describe ".compatible?" do
    it "reconnaît un pont ouvert par le poids unitaire" do
      expect(described_class.compatible?(from_unit: nil, ingredient: ingredient(:mass, "g", piece_weight_g: 40)))
        .to be(true)
    end

    it "refuse le même croisement sans poids unitaire" do
      expect(described_class.compatible?(from_unit: nil, ingredient: ingredient(:mass, "g")))
        .to be(false)
    end
  end

  # Ce qui décide d'appeler l'IA. La question se pose en creux — « et si on avait
  # une densité ? » — pour ne jamais redire ici quels groupes elle relie.
  describe ".density_would_help?" do
    it "reconnaît la cuillerée de farine, qu'une densité pèserait" do
      expect(described_class.density_would_help?(from_unit: "càs", ingredient: ingredient(:mass, "g")))
        .to be(true)
    end

    it "ne réclame rien quand la densité est déjà connue" do
      farine = ingredient(:mass, "g", density: 0.55)

      expect(described_class.density_would_help?(from_unit: "càs", ingredient: farine)).to be(false)
    end

    it "ne réclame rien quand la conversion aboutit déjà" do
      expect(described_class.density_would_help?(from_unit: "càs", ingredient: ingredient(:volume, "ml")))
        .to be(false)
    end

    # Ce sont des tranches qu'il faudrait peser, pas des millilitres : aucune
    # densité ne sauverait cette conversion.
    it "ne réclame rien quand aucune densité ne débloquerait la conversion" do
      expect(described_class.density_would_help?(from_unit: "tranches", ingredient: ingredient(:mass, "g")))
        .to be(false)
      expect(described_class.density_would_help?(from_unit: nil, ingredient: ingredient(:mass, "g")))
        .to be(false)
    end
  end

  # Ce qui met la mention « estimation » sur une ligne d'import : la quantité est
  # juste, à une densité devinée près.
  describe ".estimated?" do
    it "signale une conversion qui repose sur une densité estimée" do
      farine = ingredient(:mass, "g", density: 0.55, density_source: :ai)

      expect(described_class.estimated?(from_unit: "càs", ingredient: farine)).to be(true)
    end

    it "ne signale rien quand la densité a été vérifiée" do
      farine = ingredient(:mass, "g", density: 0.55, density_source: :manual)

      expect(described_class.estimated?(from_unit: "càs", ingredient: farine)).to be(false)
    end

    # La densité est là, mais la conversion ne lui doit rien : des grammes vers
    # un ingrédient au gramme se passent de tout pont.
    it "ne signale rien quand la conversion n'a pas eu besoin de la densité" do
      farine = ingredient(:mass, "g", density: 0.55, density_source: :ai)

      expect(described_class.estimated?(from_unit: "kg", ingredient: farine)).to be(false)
    end

    it "ne signale rien quand la conversion échoue de toute façon" do
      farine = ingredient(:mass, "g", density: 0.55, density_source: :ai)

      expect(described_class.estimated?(from_unit: "tranches", ingredient: farine)).to be(false)
    end
  end
end
