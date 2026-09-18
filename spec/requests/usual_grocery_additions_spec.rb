# frozen_string_literal: true

require "rails_helper"

# La pop-up « Mes habituelles » de la liste de courses (UC8, étape 3) : on y
# décoche ce dont on n'a pas besoin cette fois, on ajuste une quantité, et le
# reste rejoint la liste.
RSpec.describe "Courses habituelles sur la liste de courses", type: :request do
  let(:user) { create(:user) }
  let(:menu) { create(:menu, user: user, status: :active) }

  before { sign_in user }

  def usual(**attributes)
    user.household.usual_grocery_items.create!(**attributes)
  end

  describe "GET la liste de courses" do
    it "propose le bouton « Mes habituelles » et sa pop-up" do
      get grocery_menu_path(menu)

      expect(response.body).to include("Mes habituelles", "usual-groceries", usual_menu_grocery_items_path(menu))
    end

    it "marque une ligne entièrement habituelle, et dit la part habituelle d'une ligne qui cumule" do
      create(:grocery_item, menu: menu, ingredient: nil, source: :manual, name: "Dentifrice",
                            base_unit: "piece", quantity_base: 1, usual_quantity_base: 1)
      create(:grocery_item, menu: menu, source: :generated, name: "Lait",
                            base_unit: "ml", quantity_base: 6500, usual_quantity_base: 6000)

      get grocery_menu_path(menu)

      expect(response.body).to include("Course habituelle", "dont 6 L de tes habituelles")
    end

    it "ne marque ni les lignes du menu ni les ajouts ponctuels" do
      create(:grocery_item, menu: menu, source: :generated, name: "Farine")
      create(:grocery_item, menu: menu, ingredient: nil, source: :manual, name: "Éponges")

      get grocery_menu_path(menu)

      expect(response.body).not_to include("grocery-item-usual")
    end

    it "coiffe chaque rayon d'un bandeau à ses couleurs" do
      create(:grocery_item, menu: menu, source: :generated, name: "Farine", category: :epicerie_salee)

      get grocery_menu_path(menu)

      expect(response.body).to include('data-category="epicerie_salee"', "grocery-section-title", "category-dot")
    end

    # Un rappel au bon moment, pas une barre permanente : il disparaît dès que
    # les habituels ont rejoint la liste.
    describe "rappel des habituels en tête de liste" do
      it "invite à les ajouter tant qu'ils n'y sont pas" do
        %w[Beurre Cafe Dentifrice Lait].each { |name| usual(name: name) }

        get grocery_menu_path(menu)

        expect(response.body).to include("Tes 4 courses habituelles ne sont pas encore sur cette liste",
                                         "Beurre, Cafe, Dentifrice…", "Choisir mes habituelles")
      end

      it "se tait une fois les habituels ajoutés" do
        usual(name: "Dentifrice")
        create(:grocery_item, menu: menu, ingredient: nil, source: :manual, name: "Dentifrice",
                              base_unit: "piece", quantity_base: 1, usual_quantity_base: 1)

        get grocery_menu_path(menu)

        expect(response.body).not_to include("Choisir mes habituelles")
      end

      it "se tait quand le foyer n'a pas d'habituels" do
        get grocery_menu_path(menu)

        expect(response.body).not_to include("Choisir mes habituelles")
      end
    end
  end

  describe "GET la pop-up" do
    it "liste les habituels cochés, avec leur quantité et leur rayon" do
      usual(name: "Lait", quantity: 6, unit: "l", category: "produits_laitiers")

      get usual_menu_grocery_items_path(menu)

      expect(response.body).to include("Lait", 'value="6"', "L</span>", "Modifier ma liste",
                                       "Tout cocher", "Tout décocher", 'data-category="produits_laitiers"')
      expect(response.body).to match(/type="checkbox"[^>]*checked="checked"/)
    end

    # − / + avancent par 50 g : à l'unité, des grammes ne bougeraient pas à l'œil
    it "règle le pas des boutons − / + sur l'unité" do
      usual(name: "Riz", quantity: 500, unit: "g")
      usual(name: "Éponges", quantity: 3)

      get usual_menu_grocery_items_path(menu)

      expect(response.body).to include('data-number-stepper-increment-value="50"',
                                       'data-number-stepper-increment-value="1"')
    end

    # Pour ne pas les ajouter deux fois
    it "décoche ce qui a déjà rejoint la liste" do
      usual(name: "Dentifrice")
      create(:grocery_item, menu: menu, ingredient: nil, source: :manual, name: "Dentifrice",
                            base_unit: "piece", quantity_base: 1, usual_quantity_base: 1)

      get usual_menu_grocery_items_path(menu)

      expect(response.body).to include("Déjà ajouté")
      expect(response.body).not_to match(/type="checkbox"[^>]*checked/)
    end

    it "propose de reprendre les ajouts ponctuels quand les habituels sont vides" do
      create(:grocery_item, menu: menu, ingredient: nil, source: :manual, name: "Éponges")
      create(:grocery_item, menu: menu, ingredient: nil, source: :manual, name: "Piles")

      get usual_menu_grocery_items_path(menu)

      expect(response.body).to include("Créer ma liste", "Reprendre les 2 articles ajoutés à la main",
                                       import_household_usual_grocery_items_path)
    end

    it "ne propose que de créer la liste quand il n'y a rien à reprendre" do
      get usual_menu_grocery_items_path(menu)

      expect(response.body).to include("Créer ma liste")
      expect(response.body).not_to include("Reprendre")
    end

    it "est refusée hors du foyer du menu" do
      sign_in create(:user)

      get usual_menu_grocery_items_path(menu)

      expect(response).to redirect_to(root_path)
    end
  end

  describe "POST les habituels retenus" do
    def post_items(items)
      post usual_menu_grocery_items_path(menu), params: { items: items }
    end

    it "ajoute les articles cochés, avec la quantité de cette fois, puis revient sur la liste" do
      dentifrice = usual(name: "Dentifrice", category: "hygiene_beaute")
      eponges = usual(name: "Éponges", quantity: 2)

      post_items(dentifrice.id => { selected: "1", quantity: "1" },
                 eponges.id => { quantity: "2" })

      expect(response).to redirect_to(grocery_menu_path(menu))
      expect(flash[:notice]).to eq("1 article ajouté à ta liste.")
      expect(menu.grocery_items.sole).to have_attributes(name: "Dentifrice", usual_quantity_base: 1)
    end

    it "écarte un article sans quantité" do
      eponges = usual(name: "Éponges")

      post_items(eponges.id => { selected: "1", quantity: "0" })

      expect(menu.grocery_items).to be_empty
      expect(flash[:alert]).to eq("Aucun article n'a été ajouté.")
    end

    it "ignore une course habituelle d'un autre foyer" do
      foreign = create(:usual_grocery_item, name: "Caviar")

      post_items(foreign.id => { selected: "1", quantity: "3" })

      expect(menu.grocery_items).to be_empty
    end

    it "est refusé hors du foyer du menu" do
      dentifrice = usual(name: "Dentifrice")
      sign_in create(:user)

      post_items(dentifrice.id => { selected: "1", quantity: "1" })

      expect(menu.grocery_items).to be_empty
    end
  end

  # Règle 7 : la part du menu est recalculée à chaque validation, une correction
  # à la main porte donc sur la part habituelle.
  describe "PATCH la quantité d'une ligne qui cumule menu et habituels" do
    it "reporte la correction sur la part habituelle" do
      line = create(:grocery_item, menu: menu, source: :generated, base_unit: "ml",
                                   quantity_base: 6500, usual_quantity_base: 6000)

      patch menu_grocery_item_path(menu, line), params: { grocery_item: { quantity_base: 4500 } }

      expect(line.reload).to have_attributes(quantity_base: 4500, usual_quantity_base: 4000)
    end
  end
end
