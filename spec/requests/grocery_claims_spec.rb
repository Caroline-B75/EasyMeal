# frozen_string_literal: true

require "rails_helper"

# « Je m'en occupe » : la liste de courses d'un foyer se répartit entre ses
# membres — l'une au marché, l'autre au supermarché. Chacun prend pour soi,
# article par article ou rayon par rayon, et voit qui s'occupe de quoi.
RSpec.describe "Répartition de la liste de courses", type: :request do
  let(:caroline) { create(:user, username: "Caro") }
  let(:marc) { create(:user, username: "marc").tap { |member| caroline.household.admit!(member) } }
  let(:menu) { create(:menu, user: caroline, status: :active) }
  let!(:carottes) { create(:grocery_item, menu: menu, name: "Carottes", category: :fruits_legumes) }
  let!(:tomates) { create(:grocery_item, menu: menu, name: "Tomates", category: :fruits_legumes) }
  let!(:jus) { create(:grocery_item, menu: menu, name: "Jus d'orange", category: :boissons) }

  describe "un article" do
    before { sign_in marc }

    it "se prend pour soi, et la réponse re-rend son rayon" do
      patch claim_menu_grocery_item_path(menu, carottes), as: :turbo_stream

      expect(carottes.reload.claimed_by).to eq(marc)
      expect(response.media_type).to eq("text/vnd.turbo-stream.html")
      expect(response.body).to include('target="grocery_section_fruits_legumes"')
    end

    it "se reprend à un autre membre" do
      carottes.claim!(caroline)

      patch claim_menu_grocery_item_path(menu, carottes), as: :turbo_stream

      expect(carottes.reload.claimed_by).to eq(marc)
    end

    it "se laisse seulement si on l'avait pris soi-même" do
      carottes.claim!(caroline)
      tomates.claim!(marc)

      delete claim_menu_grocery_item_path(menu, carottes), as: :turbo_stream
      delete claim_menu_grocery_item_path(menu, tomates), as: :turbo_stream

      expect(carottes.reload.claimed_by).to eq(caroline)
      expect(tomates.reload.claimed_by).to be_nil
    end

    it "revient à qui le coche" do
      carottes.claim!(caroline)

      patch menu_grocery_item_path(menu, carottes), params: { grocery_item: { checked: true } }, as: :turbo_stream

      expect(carottes.reload).to have_attributes(checked: true, claimed_by: marc)
    end
  end

  describe "un rayon" do
    before { sign_in marc }

    it "se prend d'un geste, sans reprendre ce qu'un autre membre a déjà pris" do
      tomates.claim!(caroline)

      patch claim_section_menu_grocery_items_path(menu), params: { category: "fruits_legumes" }, as: :turbo_stream

      expect(carottes.reload.claimed_by).to eq(marc)
      expect(tomates.reload.claimed_by).to eq(caroline)
      expect(jus.reload.claimed_by).to be_nil
    end

    it "se laisse d'un geste" do
      menu.claim_grocery_section!("fruits_legumes", marc)

      delete claim_section_menu_grocery_items_path(menu), params: { category: "fruits_legumes" }, as: :turbo_stream

      expect([ carottes, tomates ].map { |item| item.reload.claimed_by }).to all(be_nil)
    end

    it "refuse un rayon inconnu" do
      patch claim_section_menu_grocery_items_path(menu), params: { category: "rayon-forge" }, as: :turbo_stream

      expect(response).to have_http_status(:not_found)
    end
  end

  it "reste fermée aux comptes hors du foyer" do
    sign_in create(:user)

    patch claim_menu_grocery_item_path(menu, carottes), as: :turbo_stream

    expect(carottes.reload.claimed_by).to be_nil
  end

  describe "GET la liste" do
    it "s'abonne au flux de la liste, rafraîchi en morph" do
      sign_in caroline

      get grocery_menu_path(menu)

      expect(response.body).to include("turbo-cable-stream-source", 'name="turbo-refresh-method" content="morph"',
                                       'name="turbo-refresh-scroll" content="preserve"')
    end

    it "n'offre rien à répartir à qui est seul dans son foyer" do
      sign_in caroline

      get grocery_menu_path(menu)

      expect(response.body).not_to include("grocery-mode-switch", "Ma part", "Je prends")
    end

    context "dans un foyer partagé" do
      before { marc }

      it "propose les modes Courses et Répartir et le filtre « Ma part »" do
        sign_in caroline

        get grocery_menu_path(menu)

        expect(response.body).to include("grocery-mode-switch", "Répartir", "Ma part", "Je prends", "Tout prendre")
      end

      it "affiche le pseudo une seule fois quand un membre a pris tout le rayon" do
        menu.claim_grocery_section!("fruits_legumes", marc)
        sign_in caroline

        get grocery_menu_path(menu)

        section = Nokogiri::HTML(response.body).at_css("#grocery_section_fruits_legumes")
        expect(section.css(".grocery-section-header .grocery-claim-chip").map(&:text)).to eq([ "@marc" ])
        expect(section.css(".grocery-item-main .grocery-claim-chip")).to be_empty
      end

      it "affiche le pseudo sur chaque ligne prise quand le rayon est partagé" do
        carottes.claim!(marc)
        sign_in caroline

        get grocery_menu_path(menu)

        section = Nokogiri::HTML(response.body).at_css("#grocery_section_fruits_legumes")
        expect(section.css(".grocery-section-header .grocery-claim-chip")).to be_empty
        expect(section.css(".grocery-item-main .grocery-claim-chip").map(&:text)).to eq([ "@marc" ])
      end

      it "marque chaque ligne pour le filtre « Ma part »" do
        carottes.claim!(marc)
        tomates.claim!(caroline)
        sign_in caroline

        get grocery_menu_path(menu)

        claims = Nokogiri::HTML(response.body).css(".grocery-item").to_h do |row|
          [ row.at_css(".grocery-item-name").text, row["data-claim"] ]
        end
        expect(claims).to eq("Carottes" => "other", "Tomates" => "mine", "Jus d'orange" => "free")
      end
    end
  end
end
