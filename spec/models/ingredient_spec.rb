# frozen_string_literal: true

require "rails_helper"

RSpec.describe Ingredient, type: :model do
  describe "BASE_UNITS" do
    # Filet de sécurité : ce test casse si on ajoute un groupe d'unités à l'enum
    # sans lui donner son unité de base (ou l'inverse).
    it "définit exactement une unité de base par groupe d'unités de l'enum" do
      expect(Ingredient::BASE_UNITS.keys).to match_array(Ingredient.unit_groups.keys)
    end
  end

  describe "libellés d'enum (EnumLabels)" do
    it "traduit une valeur de rayon" do
      expect(Ingredient.enum_label(:category, "fruits_legumes")).to eq("Fruits et légumes")
    end

    it "traduit une valeur de groupe d'unités" do
      expect(Ingredient.enum_label(:unit_group, "mass")).to eq("Masse (g, kg)")
    end

    # Les sélecteurs (filtre du catalogue, formulaires) affichent les rayons
    # dans l'ordre de déclaration de l'enum.
    it "expose les rayons en couples [libellé, valeur] pour les sélecteurs" do
      options = Ingredient.enum_options(:category)

      expect(options.first).to eq([ "Fruits et légumes", "fruits_legumes" ])
      expect(options.map(&:last)).to eq(Ingredient.categories.keys)
    end

    # Filet de sécurité : sans traduction, enum_label se replie silencieusement
    # sur la valeur humanisée (« Fruits legumes ») — un français approximatif qui
    # passerait inaperçu à l'écran. Ces tests cassent dès qu'une clé d'enum arrive
    # sans son libellé dans config/locales/fr.yml (ou l'inverse).
    %i[category unit_group].each do |field|
      it "traduit exactement les valeurs de l'enum #{field}, ni plus ni moins" do
        enum_name = field.to_s.pluralize
        translated = I18n.t("activerecord.attributes.ingredient.#{enum_name}").keys.map(&:to_s)

        expect(translated).to match_array(Ingredient.public_send(enum_name).keys)
      end
    end

    # GroceryItem duplique l'enum category d'Ingredient sans dupliquer ses
    # traductions : la liste de courses titre ses rayons via Ingredient.enum_label.
    # Les rayons restant alignés, le test ci-dessus couvre aussi ce cas.
    it "partage ses rayons avec ceux de la liste de courses" do
      expect(GroceryItem.categories.keys).to eq(Ingredient.categories.keys)
    end
  end

  describe "validation base_unit_matches_unit_group" do
    Ingredient::BASE_UNITS.each do |unit_group, base_unit|
      context "pour le groupe #{unit_group}" do
        it "accepte l'unité de base « #{base_unit} »" do
          ingredient = build(:ingredient, unit_group: unit_group, base_unit: base_unit)

          expect(ingredient).to be_valid
        end

        it "refuse une unité qui n'est pas « #{base_unit} »" do
          ingredient = build(:ingredient, unit_group: unit_group, base_unit: "litron")

          expect(ingredient).not_to be_valid
          expect(ingredient.errors[:base_unit])
            .to include("doit être #{base_unit} pour le groupe #{unit_group}")
        end
      end
    end
  end

  # Le poids d'une pièce fait le pont entre la recette qui compte et le
  # catalogue qui pèse (voir UnitConversionService).
  describe "validation du poids unitaire" do
    it "est facultatif" do
      expect(build(:ingredient, piece_weight_g: nil)).to be_valid
    end

    it "accepte un poids sur un ingrédient en masse" do
      expect(build(:ingredient, unit_group: :mass, base_unit: "g", piece_weight_g: 300)).to be_valid
    end

    it "accepte un poids sur un ingrédient en pièces" do
      expect(build(:ingredient, unit_group: :count, base_unit: "piece", piece_weight_g: 50)).to be_valid
    end

    it "refuse un poids nul ou négatif" do
      ingredient = build(:ingredient, piece_weight_g: 0)

      expect(ingredient).not_to be_valid
      expect(ingredient.errors[:piece_weight_g]).to include("doit être supérieur à 0")
    end

    # Ailleurs, il resterait en base sans jamais servir : aucune conversion ne
    # relie un volume ou une cuillère à un décompte.
    %i[volume spoon].each do |unit_group|
      it "refuse un poids sur un ingrédient en #{unit_group}" do
        ingredient = build(:ingredient,
                           unit_group: unit_group,
                           base_unit: Ingredient::BASE_UNITS[unit_group.to_s],
                           piece_weight_g: 100)

        expect(ingredient).not_to be_valid
        expect(ingredient.errors[:piece_weight_g])
          .to include("ne s'applique qu'aux ingrédients en masse ou en pièces")
      end
    end
  end

  # La densité fait le second pont : entre la recette qui mesure et le catalogue
  # qui pèse (voir UnitConversionService). Une valeur fausse fausserait des
  # quantités en silence, d'où des bornes et une provenance obligatoire.
  describe "validation de la densité" do
    def with_density(density, unit_group: :mass, source: :manual)
      build(:ingredient, unit_group: unit_group, base_unit: Ingredient::BASE_UNITS[unit_group.to_s],
                         density_g_per_ml: density, density_source: density && source)
    end

    it "est facultative" do
      expect(with_density(nil)).to be_valid
    end

    %i[mass volume spoon].each do |unit_group|
      it "accepte une densité sur un ingrédient en #{unit_group}" do
        expect(with_density(0.55, unit_group: unit_group)).to be_valid
      end
    end

    # Elle n'y servirait jamais : rien ne relie un décompte à un volume.
    it "refuse une densité sur un ingrédient compté à la pièce" do
      ingredient = with_density(0.55, unit_group: :count)

      expect(ingredient).not_to be_valid
      expect(ingredient.errors[:density_g_per_ml])
        .to include("ne s'applique pas aux ingrédients comptés à la pièce")
    end

    it "refuse une densité nulle ou négative" do
      expect(with_density(0)).not_to be_valid
    end

    # Garde-fou de l'estimation par l'IA : au-delà, ce n'est plus un aliment.
    it "refuse une densité hors des bornes alimentaires" do
      ingredient = with_density(Ingredient::MAX_DENSITY + 1)

      expect(ingredient).not_to be_valid
      expect(ingredient.errors[:density_g_per_ml].join)
        .to include("entre 0 et #{Ingredient::MAX_DENSITY}")
    end

    # Sans provenance, une estimation ne pourrait pas se signaler « à vérifier ».
    it "exige de dire d'où vient une densité" do
      ingredient = build(:ingredient, density_g_per_ml: 0.55, density_source: nil)

      expect(ingredient).not_to be_valid
      expect(ingredient.errors[:density_source]).to include("doit dire d'où vient la densité")
    end

    it "refuse une provenance sans densité" do
      ingredient = build(:ingredient, density_g_per_ml: nil, density_source: :ai)

      expect(ingredient).not_to be_valid
      expect(ingredient.errors[:density_source]).to include("ne se renseigne qu'avec une densité")
    end
  end
end
