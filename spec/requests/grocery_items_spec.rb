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

    # Ce que lit une suggestion pour dire « Déjà dans ta liste · 100 g »
    it "donne aux suggestions la liste, et à chaque ligne son ingrédient et sa quantité" do
      item = create(:grocery_item, menu: menu, name: "Farine T55", quantity_base: 100)

      get grocery_menu_path(menu)

      expect(response.body).to include('data-ingredient-combobox-list-value="#grocery_list"',
                                       "data-ingredient-id=\"#{item.ingredient_id}\"", 'data-quantity="100 g"')
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

  # Le beurre du menu et celui qu'on rajoute ne font qu'une ligne : la quantité
  # saisie s'additionne à la ligne qui porte déjà l'article.
  describe "article déjà présent" do
    let(:beurre) { create(:ingredient, name: "Beurre doux", unit_group: :mass, base_unit: "g") }
    let!(:line) do
      create(:grocery_item, menu: menu, ingredient: beurre, name: "Beurre doux", base_unit: "g",
                            quantity_base: 100)
    end

    it "additionne la quantité à la ligne du menu au lieu d'en créer une seconde" do
      expect { add_article(name: "Beurre doux", quantity: 250, unit: "g", ingredient_id: beurre.id) }
        .not_to change(menu.grocery_items, :count)

      expect(line.reload).to have_attributes(quantity_base: 350, extra_quantity_base: 250, source: "generated",
                                             usual_quantity_base: nil)
      expect(flash[:notice]).to eq("Beurre doux : 100 g → 350 g")
    end

    # La ligne a changé ailleurs dans la page : le message le dit, et offre de revenir en arrière
    it "le dit par un message qui offre d'annuler" do
      post menu_grocery_items_path(menu), params: { grocery_item: { name: "Beurre doux", quantity: 250, unit: "g" } },
                                          as: :turbo_stream

      expect(response.body).to include('action="update" target="flash"', "Beurre doux : 100 g → 350 g",
                                       "Annuler", addition_menu_grocery_item_path(menu, line))
    end

    # Une quantité qui ne ferait pas une ligne n'en entame pas une non plus
    it "refuse une quantité nulle ou négative sans toucher la ligne" do
      [ 0, -50 ].each { |quantity| add_article(name: "Beurre doux", quantity: quantity, unit: "g") }

      expect(line.reload.quantity_base).to eq(100)
      expect(flash[:alert]).to include("doit être supérieure à 0")
    end

    # Une correction à la main porte sur ce qui a été ajouté en plus
    it "reporte une correction de la quantité sur la part ajoutée en plus" do
      add_article(name: "Beurre doux", quantity: 250, unit: "g")

      patch menu_grocery_item_path(menu, line), params: { grocery_item: { quantity: 300, unit: "g" } }

      expect(line.reload).to have_attributes(quantity_base: 300, extra_quantity_base: 200)
    end

    describe "« Annuler »" do
      def add_and_capture_token
        post menu_grocery_items_path(menu), params: { grocery_item: { name: "Beurre doux", quantity: 250, unit: "g" } },
                                            as: :turbo_stream
        response.body[/name="token" value="([^"]+)"/, 1]
      end

      def cancel(token)
        delete addition_menu_grocery_item_path(menu, line), params: { token: token }, as: :turbo_stream
      end

      it "remet la ligne dans son état d'avant l'ajout, et le confirme" do
        line.update!(checked: true)

        cancel(add_and_capture_token)

        expect(line.reload).to have_attributes(quantity_base: 100, extra_quantity_base: nil, checked: true,
                                               previous_quantity_base: nil)
        expect(response.body).to include('action="update" target="flash"', "Ajout annulé.")
      end

      it "refuse quand la ligne a changé depuis" do
        token = add_and_capture_token
        line.update!(quantity_base: 500)

        cancel(token)

        expect(line.reload.quantity_base).to eq(500)
        expect(response.body).to include("a changé depuis")
      end

      it "est refusé hors du foyer du menu" do
        token = add_and_capture_token
        sign_in create(:user)

        cancel(token)

        expect(line.reload.quantity_base).to eq(350)
      end
    end

    it "convertit la saisie dans l'unité de la ligne avant de l'additionner" do
      add_article(name: "beurre doux", quantity: 1, unit: "kg")

      expect(line.reload.quantity_base).to eq(1100)
    end

    # Ce qui a été acheté ne suffit plus : la ligne se décoche et le badge dit
    # combien l'était déjà — même règle qu'une hausse venue du menu.
    it "décoche une ligne déjà achetée, en retenant ce qui l'a été" do
      line.update!(checked: true)

      add_article(name: "Beurre doux", quantity: 250, unit: "g", ingredient_id: beurre.id)

      expect(line.reload).to have_attributes(quantity_base: 350, checked: false, previous_quantity_base: 100)
    end

    # Ce qu'on rajoute à la main n'est pas une course habituelle : la note
    # « dont … de tes habituelles » continue de dire la seule part habituelle.
    it "laisse la part habituelle de la ligne telle quelle" do
      line.update!(source: :manual, quantity_base: 500, usual_quantity_base: 500)

      add_article(name: "Beurre doux", quantity: 250, unit: "g", ingredient_id: beurre.id)

      expect(line.reload).to have_attributes(quantity_base: 750, usual_quantity_base: 500)
    end

    # Une ligne libre n'a pas d'ingrédient pour la reconnaître : c'est son nom
    # qui la désigne, aux accents et à la casse près.
    it "reconnaît un article libre écrit différemment" do
      eponges = create(:grocery_item, menu: menu, ingredient: nil, name: "Éponges", source: :manual,
                                      base_unit: "piece", quantity_base: 3)

      expect { add_article(name: "eponges", quantity: 2, unit: "piece") }
        .not_to change(menu.grocery_items, :count)

      expect(eponges.reload.quantity_base).to eq(5)
    end

    # Des paquets face à des grammes ne s'additionnent pas : l'article prend une
    # ligne à part plutôt que de fausser la quantité.
    it "donne une ligne à part à un article dont l'unité ne s'additionne pas" do
      create(:grocery_item, menu: menu, ingredient: nil, name: "Café", source: :manual,
                            base_unit: "g", quantity_base: 250)

      add_article(name: "Café", quantity: 2, unit: "piece", category: "epicerie_sucree")

      expect(menu.grocery_items.where(name: "Café").pluck(:base_unit, :quantity_base))
        .to contain_exactly([ "g", 250 ], [ "piece", 2 ])
    end

    # La ligne existante se cherche dans SA liste : deux utilisatrices peuvent
    # acheter des éponges la même semaine.
    it "ignore les listes des autres menus" do
      elsewhere = create(:grocery_item, menu: create(:menu, user: user), ingredient: nil, name: "Éponges",
                                        base_unit: "piece", quantity_base: 3)

      add_article(name: "Éponges", quantity: 2, unit: "piece")

      expect(menu.grocery_items.find_by!(name: "Éponges").quantity_base).to eq(2)
      expect(elsewhere.reload.quantity_base).to eq(3)
    end
  end

  # On corrige une quantité dans l'unité où l'on achète : « 2 plaquettes », pas « 500 g »
  describe "PATCH la quantité dans l'unité choisie" do
    let!(:line) do
      create(:grocery_item, menu: menu, name: "Beurre doux", unit_group: :mass, base_unit: "g", quantity_base: 40,
                            piece_label: "plaquette", piece_weight_g: 250)
    end

    it "propose la plaquette, sélectionnée, sur le compte qu'affiche la ligne" do
      get grocery_menu_path(menu)

      expect(response.body).to include('value="1"', 'data-quantity="40" value="g"')
      expect(response.body).to include('data-quantity="1" selected="selected" value="piece">plaquette<')
    end

    it "ramène les plaquettes saisies en grammes" do
      patch menu_grocery_item_path(menu, line), params: { grocery_item: { quantity: 2, unit: "piece" } }

      expect(line.reload.quantity_base).to eq(500)
    end

    it "refuse une unité qui ne convient pas à la ligne" do
      patch menu_grocery_item_path(menu, line), params: { grocery_item: { quantity: 1, unit: "l" } }

      expect(line.reload.quantity_base).to eq(40)
      expect(flash[:alert]).to eq("L'unité « L » ne convient pas à Beurre doux")
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
