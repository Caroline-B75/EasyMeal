# frozen_string_literal: true

require "rails_helper"

# UC3 — Ajout manuel d'un article à la liste de courses.
#
# Deux chemins pour une seule saisie : l'article est au catalogue et
# l'autocomplétion l'a rattaché (ou son nom suffit à le retrouver), ou il n'y
# est pas et se décrit lui-même. Dans les deux cas la quantité saisie rejoint
# l'unité de base de la ligne : c'est elle, et elle seule, que la colonne
# `quantity_base` retient.
RSpec.describe "Ajout manuel à la liste de courses", type: :request do
  let(:user) { create(:user) }
  let(:menu) { create(:menu, user: user, status: :active) }

  before { sign_in user }

  def add_article(params)
    post menu_grocery_items_path(menu), params: { grocery_item: params }
  end

  # La page elle-même : aucune spec ne la rendait, et une erreur de syntaxe dans
  # le formulaire d'ajout ne se voyait donc qu'à l'écran.
  describe "GET la page de la liste de courses" do
    it "affiche le formulaire d'ajout branché sur la recherche du catalogue" do
      create(:grocery_item, menu: menu, name: "Farine T55")

      get grocery_menu_path(menu)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Ajouter un article", "Farine T55",
                                       "ingredient-combobox",
                                       "data-ingredient-combobox-search-url-value=\"#{search_ingredients_path}\"")
    end
  end

  describe "article hors catalogue" do
    it "crée une ligne libre décrite par la saisie" do
      add_article(name: "Éponges", quantity: 3, unit: "piece", category: "entretien_maison")

      item = menu.grocery_items.sole
      expect(item).to have_attributes(name: "Éponges", ingredient_id: nil, source: "manual",
                                      category: "entretien_maison", base_unit: "piece",
                                      unit_group: "count", quantity_base: 3)
    end

    # Le sélecteur propose « kg » et « L », mais la colonne ne stocke qu'un
    # nombre, toujours relu dans l'unité de base de son groupe : sans conversion,
    # « 2 kg de farine » se relisait « 2 g ».
    it "ramène la quantité à l'unité de base du groupe" do
      add_article(name: "Farine de sarrasin", quantity: 2, unit: "kg", category: "epicerie_salee")

      expect(menu.grocery_items.sole).to have_attributes(base_unit: "g", unit_group: "mass",
                                                         quantity_base: 2000)
    end

    it "compte à la pièce ce qu'on ajoute sans quantité ni unité" do
      add_article(name: "Pain", category: "boulangerie_patisserie")

      expect(menu.grocery_items.sole).to have_attributes(base_unit: "piece", quantity_base: 1)
    end

    # Un rayon inconnu lèverait à l'assignation de l'enum : la ligne se range
    # sous « divers » plutôt que de rendre une erreur 500.
    it "ignore un rayon que la liste ne connaît pas" do
      add_article(name: "Éponges", quantity: 2, unit: "piece", category: "rayon-forgé")

      expect(menu.grocery_items.sole).to have_attributes(name: "Éponges", category: nil)
    end

    it "refuse un article sans nom" do
      add_article(name: "  ", quantity: 2, unit: "g")

      expect(menu.grocery_items).to be_empty
      expect(flash[:alert]).to include("ne peut pas être vide")
    end
  end

  describe "article du catalogue" do
    let!(:vin) do
      create(:ingredient, name: "Vin blanc sec", category: :boissons,
                          unit_group: :volume, base_unit: "ml")
    end

    # Le rayon et l'unité viennent de l'ingrédient, jamais du formulaire : le
    # navigateur n'a pas à décider dans quel rayon ranger une bouteille de vin.
    it "recopie le rayon et l'unité de l'ingrédient rattaché" do
      add_article(name: "Vin blanc sec", quantity: 20, unit: "cl",
                  category: "hygiene_beaute", ingredient_id: vin.id)

      expect(menu.grocery_items.sole).to have_attributes(ingredient_id: vin.id, category: "boissons",
                                                         base_unit: "ml", quantity_base: 200)
    end

    # Le rattrapage sans JavaScript, et pour la saisie validée sans choisir de
    # suggestion : le nom seul suffit à retrouver l'ingrédient.
    it "rattache l'article par son nom quand aucun ingrédient n'est transmis" do
      add_article(name: "vin blanc sec", quantity: 1, unit: "l")

      expect(menu.grocery_items.sole).to have_attributes(ingredient_id: vin.id, name: "Vin blanc sec",
                                                         quantity_base: 1000)
    end

    it "rattache aussi l'article par l'un de ses alias" do
      vin.update!(aliases: [ "vin de cuisine" ])

      add_article(name: "Vin de cuisine", quantity: 25, unit: "cl")

      expect(menu.grocery_items.sole).to have_attributes(ingredient_id: vin.id, name: "Vin blanc sec")
    end

    # Le sélecteur d'unité se restreint aux unités de l'ingrédient dès qu'il est
    # reconnu : n'arrive ici qu'une saisie qui a contourné ce garde-fou.
    it "refuse une unité que l'ingrédient ne sait pas lire" do
      poulet = create(:ingredient, name: "Blanc de poulet", unit_group: :mass, base_unit: "g")

      add_article(name: "Blanc de poulet", quantity: 2, unit: "cas", ingredient_id: poulet.id)

      expect(menu.grocery_items).to be_empty
      expect(flash[:alert]).to include("ne se mesure pas en càs")
    end
  end

  describe "article déjà présent" do
    # Pas de fusion des quantités : la ligne existante est peut-être déjà cochée,
    # et c'est elle qu'on veut ajuster. On le dit, on n'écrit rien.
    it "renvoie vers la ligne existante au lieu d'en créer une seconde" do
      ingredient = create(:ingredient, name: "Beurre doux")
      create(:grocery_item, menu: menu, ingredient: ingredient, name: "Beurre doux")

      expect { add_article(name: "Beurre doux", quantity: 250, unit: "g", ingredient_id: ingredient.id) }
        .not_to change(menu.grocery_items, :count)

      expect(flash[:notice]).to include("Beurre doux", "déjà dans votre liste")
    end

    # Une ligne libre n'a pas d'ingrédient pour la reconnaître : c'est son nom
    # qui la désigne, aux accents et à la casse près.
    it "reconnaît un article libre écrit différemment" do
      create(:grocery_item, menu: menu, ingredient: nil, name: "Éponges", source: :manual)

      expect { add_article(name: "eponges", quantity: 2, unit: "piece") }
        .not_to change(menu.grocery_items, :count)

      expect(flash[:notice]).to include("déjà dans votre liste")
    end

    # Le doublon se cherche dans SA liste : deux utilisatrices peuvent acheter
    # du beurre la même semaine.
    it "ignore les listes des autres menus" do
      create(:grocery_item, menu: create(:menu, user: user), name: "Éponges")

      add_article(name: "Éponges", quantity: 2, unit: "piece")

      expect(menu.grocery_items.sole.name).to eq("Éponges")
    end
  end

  describe "autorisation" do
    it "refuse d'ajouter un article à la liste d'une autre personne" do
      other_menu = create(:menu, user: create(:user), status: :active)

      post menu_grocery_items_path(other_menu), params: { grocery_item: { name: "Éponges" } }

      expect(response).to have_http_status(:redirect)
      expect(other_menu.grocery_items).to be_empty
    end
  end
end
