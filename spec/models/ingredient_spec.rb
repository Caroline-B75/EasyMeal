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

  # Ce que les recettes déjà écrites imposent à l'ingrédient : elles le retiennent
  # (ni suppression ni changement d'unité) et se comptent.
  describe "emploi dans les recettes" do
    let(:ingredient) { create(:ingredient, name: "Farine", unit_group: :mass, base_unit: "g") }

    # Une recette publiée exige au moins un ingrédient : la préparation part avec.
    def recipe_using(ingredient, quantity: 100)
      recipe = build(:recipe, default_servings: 1)
      recipe.preparations.build(ingredient: ingredient, quantity_base: quantity)
      recipe.save!
      recipe
    end

    describe "#recipes_count" do
      it "compte les recettes qui emploient l'ingrédient" do
        2.times { recipe_using(ingredient) }

        expect(ingredient.recipes_count).to eq(2)
        expect(ingredient).to be_used_in_recipes
      end

      it "vaut zéro tant qu'aucune recette ne l'emploie" do
        expect(ingredient.recipes_count).to eq(0)
        expect(ingredient).not_to be_used_in_recipes
      end

      # Le catalogue affiche ce décompte sur chaque ligne : with_recipes_count le
      # ramène avec la requête de liste, plutôt qu'un COUNT par ingrédient.
      it "est ramené par with_recipes_count avec la requête de liste" do
        recipe_using(ingredient)
        loaded = Ingredient.with_recipes_count.find(ingredient.id)

        expect(loaded.attributes).to include("recipes_count" => 1)
      end
    end

    describe "#recipes_usage_label" do
      it "écrit le décompte en français, au singulier comme au pluriel" do
        recipe_using(ingredient)
        expect(ingredient.reload.recipes_usage_label).to eq("1 recette")

        recipe_using(ingredient)
        expect(ingredient.reload.recipes_usage_label).to eq("2 recettes")
      end
    end

    describe ".sorted_by" do
      let!(:sel) { create(:ingredient, name: "Sel") }

      before { 2.times { recipe_using(ingredient) } }

      it "range les ingrédients du plus employé au moins employé" do
        expect(Ingredient.with_recipes_count.sorted_by("recipes_count", "desc").map(&:name))
          .to eq([ "Farine", "Sel" ])
      end

      it "inverse l'ordre à la demande" do
        expect(Ingredient.with_recipes_count.sorted_by("recipes_count", "asc").map(&:name))
          .to eq([ "Sel", "Farine" ])
      end

      # Liste blanche : rien de ce qui vient de l'URL n'entre dans le ORDER BY.
      # Seule la colonne est écartée — le sens demandé, lui, reste appliqué.
      it "ignore une colonne inconnue et retombe sur le tri par nom" do
        expect(Ingredient.sorted_by("aliases; DROP TABLE ingredients", "asc").map(&:name))
          .to eq([ "Farine", "Sel" ])
      end

      # Le nom se trie désaccentué, sans quoi « Échalote » partirait après les Z.
      it "trie les accents à leur place alphabétique" do
        echalote = create(:ingredient, name: "Échalote")

        expect(Ingredient.sorted_by("name", "asc").map(&:name))
          .to eq([ echalote.name, "Farine", "Sel" ])
      end
    end

    describe "verrou du groupe d'unités" do
      # quantity_base ne stocke qu'un nombre : changer le groupe d'unités
      # relirait « 100 g de farine » en « 100 farines » dans chaque recette.
      it "refuse de changer d'unité dès qu'une recette emploie l'ingrédient" do
        recipe_using(ingredient)

        ingredient.assign_attributes(unit_group: :count, base_unit: "piece")

        expect(ingredient).not_to be_valid
        expect(ingredient.errors[:unit_group].join).to include("utilisé dans 1 recette")
        expect(ingredient.reload.unit_group).to eq("mass")
      end

      it "laisse changer d'unité tant qu'aucune recette ne l'emploie" do
        expect(ingredient.update(unit_group: :count, base_unit: "piece")).to be true
      end

      # Le verrou ne porte que sur l'unité : le reste de la fiche reste éditable.
      it "laisse modifier les autres attributs d'un ingrédient employé" do
        recipe_using(ingredient)

        expect(ingredient.update(name: "Farine T55", category: :epicerie_sucree)).to be true
      end
    end

    describe "suppression" do
      it "retient l'ingrédient employé par une recette" do
        recipe_using(ingredient)

        expect(ingredient.destroy).to be false
        expect(Ingredient.exists?(ingredient.id)).to be true
      end

      it "laisse partir un ingrédient qu'aucune recette n'emploie" do
        expect(ingredient.destroy).to be_truthy
      end
    end
  end
end
