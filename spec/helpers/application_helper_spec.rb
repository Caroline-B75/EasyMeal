require "rails_helper"

RSpec.describe ApplicationHelper, type: :helper do
  let(:user) { create(:user) }

  describe "#greeting_context" do
    it "annonce une liste prête uniquement pour un menu actif avec articles" do
      active_menu = create(:menu, user: user, status: :active)
      create(:grocery_item, menu: active_menu)

      expect(helper.greeting_context(active_menu: active_menu, draft: nil)).to eq(:grocery_list_ready)
    end

    it "distingue un menu actif sans liste de courses" do
      active_menu = create(:menu, user: user, status: :active)

      expect(helper.greeting_context(active_menu: active_menu, draft: nil)).to eq(:active_menu_ready)
    end

    it "n'annonce pas une liste prête pour un menu en revalidation" do
      draft = create(:menu, user: user, status: :draft)
      create(:grocery_item, menu: draft)

      expect(helper.greeting_context(active_menu: nil, draft: draft)).to eq(:pending_revalidation)
    end

    it "invite à valider un brouillon sans liste" do
      draft = create(:menu, user: user, status: :draft)

      expect(helper.greeting_context(active_menu: nil, draft: draft)).to eq(:draft_ready)
    end
  end

  describe "#inline_svg" do
    let(:icon_path) { ApplicationHelper::ICONS_PATH.join("cook-book.svg") }

    # Le cache mémoire des sources SVG survit d'un exemple à l'autre : on repart
    # d'une ardoise vierge pour compter les lectures disque.
    before { ApplicationHelper::SVG_SOURCES.delete("cook-book") }

    it "injecte les classes et l'attribut aria-hidden dans la balise svg" do
      html = helper.inline_svg("cook-book", css_class: "icon-title")

      expect(html).to include('<svg class="svg-icon icon-title" aria-hidden="true"')
      expect(html).to be_html_safe
    end

    it "renvoie une chaîne vide pour une icône inexistante" do
      html = helper.inline_svg("icone-qui-nexiste-pas")

      expect(html).to eq("")
      expect(html).to be_html_safe
    end

    it "traduit color, color2 et size en style inline" do
      html = helper.inline_svg("cook-book", color: "var(--color-primary)",
                                            color2: "var(--color-secondary)", size: "24px")

      expect(html).to include(
        'style="color: var(--color-primary); --icon-color-2: var(--color-secondary); width: 24px; height: 24px"'
      )
    end

    it "n'ajoute pas d'attribut style sans option de couleur ni de taille" do
      expect(helper.inline_svg("cook-book")).not_to include("style=\"color")
    end

    it "ne lit le fichier qu'une fois : les appels suivants viennent du cache" do
      allow(File).to receive(:read).and_call_original

      2.times { helper.inline_svg("cook-book") }

      expect(File).to have_received(:read).with(icon_path).once
    end

    it "relit le fichier à chaque appel quand le rechargement de code est actif" do
      allow(Rails.application.config).to receive(:enable_reloading).and_return(true)
      allow(File).to receive(:read).and_call_original

      2.times { helper.inline_svg("cook-book") }

      expect(File).to have_received(:read).with(icon_path).twice
    end
  end
end
