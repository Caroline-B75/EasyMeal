# frozen_string_literal: true

require "rails_helper"

RSpec.describe GroceryItem, type: :model do
  describe "effacement du badge (previous_quantity_base) au cochage" do
    it "efface previous_quantity_base quand l'article passe à coché" do
      item = create(:grocery_item, checked: false, previous_quantity_base: 50)

      item.update!(checked: true)

      expect(item.reload.previous_quantity_base).to be_nil
    end

    it "conserve previous_quantity_base tant que l'article reste décoché" do
      item = create(:grocery_item, checked: false, previous_quantity_base: 50)

      item.update!(quantity_base: 30)

      expect(item.reload.previous_quantity_base).to eq(50)
    end
  end

  describe "#previous_quantity_display" do
    it "humanise l'ancienne quantité comme quantity_display" do
      item = build(:grocery_item, unit_group: :mass, base_unit: "g", previous_quantity_base: 1500)

      expect(item.previous_quantity_display).to eq("1,5 kg")
    end
  end

  describe "affichage d'une quantité minuscule (jamais « 0 »)" do
    it "montre la valeur exacte plutôt que 0 pour une petite masse" do
      item = build(:grocery_item, unit_group: :mass, base_unit: "g", quantity_base: 0.003)

      expect(item.quantity_display).to eq("0,003 g")
    end

    it "montre la valeur exacte plutôt que 0 pour un petit comptage" do
      item = build(:grocery_item, unit_group: :count, base_unit: "piece", quantity_base: 0.03)

      expect(item.quantity_display).to eq("0,03")
    end
  end

  # « Je m'en occupe » : répartir la liste entre les membres du foyer.
  describe "prise en charge" do
    let(:caroline) { create(:user) }
    let(:marc) { create(:user) }
    let(:item) { create(:grocery_item) }

    it "prend l'article, y compris quand un autre membre l'avait pris" do
      item.claim!(marc)
      item.claim!(caroline)

      expect(item.reload.claimed_by).to eq(caroline)
    end

    it "ne laisse que l'article qu'on avait pris soi-même" do
      item.claim!(marc)

      item.release!(caroline)
      expect(item.reload.claimed_by).to eq(marc)

      item.release!(marc)
      expect(item.reload.claimed_by).to be_nil
    end

    it "donne l'article à qui le coche, sans rien changer au décochage" do
      item.claim!(marc)

      item.assign_attributes(checked: true)
      item.assign_buyer(caroline)
      item.save!
      expect(item.reload.claimed_by).to eq(caroline)

      item.assign_attributes(checked: false)
      item.assign_buyer(marc)
      item.save!
      expect(item.reload.claimed_by).to eq(caroline)
    end

    it "dit ce qu'est l'article pour chaque membre" do
      expect(item.claim_state_for(caroline)).to eq("free")

      item.claim!(marc)

      expect(item.claim_state_for(marc)).to eq("mine")
      expect(item.claim_state_for(caroline)).to eq("other")
    end
  end

  # La liste partagée se met à jour sur les autres écrans ouverts : chaque
  # changement publie une demande de rafraîchissement sur le flux du menu.
  describe "temps réel" do
    it "demande aux écrans ouverts sur la liste de se rafraîchir" do
      item = create(:grocery_item)
      # Nom du flux tel que Turbo le dérive de Menu#grocery_stream
      stream = "#{item.menu.to_gid_param}:grocery"

      expect { item.update!(checked: true) }
        .to have_enqueued_job(Turbo::Streams::BroadcastStreamJob)
        .with(stream, content: include('action="refresh"'))
    end
  end

  # 500 ml pour une recette, 6 L d'habitude
  def mixed_line(**overrides)
    create(:grocery_item, **{ base_unit: "ml", quantity_base: 6500, usual_quantity_base: 6000 }.merge(overrides))
  end

  # Courses habituelles (UC8, étape 3) : une ligne additionne sa part (menu ou
  # ajout ponctuel) et sa part habituelle.
  describe "part habituelle" do
    it "distingue une ligne entièrement habituelle d'une ligne qui cumule" do
      expect(mixed_line).to be_partly_usual.and(have_attributes(usual_only?: false))
      expect(create(:grocery_item, quantity_base: 3, usual_quantity_base: 3)).to be_usual_only
      expect(create(:grocery_item)).not_to be_partly_usual
    end

    it "dit la part habituelle comme une quantité de la liste" do
      expect(mixed_line.usual_quantity_display).to eq("6 L")
    end

    describe "#reconcile_quantity" do
      it "décoche une ligne cochée qui augmente, et retient l'ancienne quantité" do
        item = create(:grocery_item, quantity_base: 100, checked: true)

        item.reconcile_quantity(150)

        expect(item).to have_attributes(quantity_base: 150, checked: false, previous_quantity_base: 100)
      end

      it "garde la coche d'une ligne qui baisse" do
        item = create(:grocery_item, quantity_base: 100, checked: true, previous_quantity_base: 80)

        item.reconcile_quantity(60)

        expect(item).to have_attributes(quantity_base: 60, checked: true, previous_quantity_base: nil)
      end
    end

    describe "#add_usual_quantity" do
      it "fait grandir d'autant le total et la part habituelle" do
        item = create(:grocery_item, base_unit: "ml", quantity_base: 500)

        item.add_usual_quantity(6000)

        expect(item).to have_attributes(quantity_base: 6500, usual_quantity_base: 6000, extra_quantity_base: nil)
      end
    end
  end

  # « Ajouter un article » sur une ligne du menu : une part ajoutée en plus,
  # conservée comme la part habituelle, jamais affichée.
  describe "part ajoutée en plus" do
    describe "#add_quantity" do
      it "fait de ce qui s'ajoute à une ligne du menu sa part ajoutée en plus" do
        item = create(:grocery_item, source: :generated, quantity_base: 100)

        2.times { item.add_quantity(250) }

        expect(item).to have_attributes(quantity_base: 600, extra_quantity_base: 500)
      end

      # Toute la quantité d'un ajout ponctuel est déjà « à la main »
      it "fait grandir la part d'un ajout ponctuel, sans part ajoutée en plus" do
        item = create(:grocery_item, source: :manual, quantity_base: 100)

        item.add_quantity(250)

        expect(item).to have_attributes(quantity_base: 350, extra_quantity_base: nil)
      end

      it "ne touche pas la part habituelle" do
        item = mixed_line(source: :generated)

        item.add_quantity(250)

        expect(item).to have_attributes(quantity_base: 6750, usual_quantity_base: 6000, extra_quantity_base: 250)
      end
    end

    it "compte ensemble ce que la ligne doit aux ajouts à la main" do
      expect(create(:grocery_item).kept_quantity_base).to eq(0)
      expect(mixed_line(quantity_base: 7000, extra_quantity_base: 500).kept_quantity_base).to eq(6500)
    end
  end

  # La part du menu est recalculée à chaque validation, celle d'un ajout ponctuel
  # ne bouge pas : une correction à la main porte sur ce qui a été ajouté à la
  # main — la part habituelle, sinon la part ajoutée en plus.
  describe "#shift_quantity_change_to_added_parts" do
    def correct(item, quantity)
      item.quantity_base = quantity
      item.shift_quantity_change_to_added_parts
      item
    end

    it "reporte une baisse sur la part habituelle" do
      expect(correct(mixed_line, 4500).usual_quantity_base).to eq(4000)
    end

    it "reporte une hausse sur la part habituelle" do
      expect(correct(mixed_line, 8500).usual_quantity_base).to eq(8000)
    end

    it "efface la part habituelle quand la correction descend sous l'autre part" do
      expect(correct(mixed_line, 400).usual_quantity_base).to be_nil
    end

    it "laisse une ligne entièrement habituelle le rester" do
      item = create(:grocery_item, quantity_base: 3, usual_quantity_base: 3)

      expect(correct(item, 5)).to be_usual_only
    end

    it "ne touche pas une ligne sans part ajoutée à la main" do
      item = correct(create(:grocery_item, quantity_base: 100), 80)

      expect(item).to have_attributes(usual_quantity_base: nil, extra_quantity_base: nil)
    end

    describe "sur une ligne du menu complétée à la main" do
      # 100 g pour le menu + 250 g en plus
      let(:item) { create(:grocery_item, source: :generated, quantity_base: 350, extra_quantity_base: 250) }

      it "reporte la correction sur la part ajoutée en plus" do
        expect(correct(item, 300).extra_quantity_base).to eq(200)
      end

      it "efface la part ajoutée en plus quand la correction descend sous le menu" do
        expect(correct(item, 80).extra_quantity_base).to be_nil
      end
    end

    # 500 ml pour le menu + 500 ml en plus + 6 L d'habitude
    describe "sur une ligne qui porte les deux parts" do
      let(:item) { mixed_line(source: :generated, quantity_base: 7000, extra_quantity_base: 500) }

      it "reporte la correction sur la part habituelle" do
        expect(correct(item, 6500)).to have_attributes(usual_quantity_base: 5500, extra_quantity_base: 500)
      end

      it "entame la part ajoutée en plus une fois la part habituelle épuisée" do
        expect(correct(item, 800)).to have_attributes(usual_quantity_base: nil, extra_quantity_base: 300)
      end
    end
  end

  # On corrige dans l'unité où l'on achète : « 2 plaquettes » de beurre, pas « 500 g »
  describe "correction de la quantité" do
    let(:beurre) do
      build(:grocery_item, name: "Beurre", unit_group: :mass, base_unit: "g", quantity_base: 40,
                           piece_label: "plaquette", piece_weight_g: 250)
    end

    it "s'ouvre en pièces sur ce qui s'achète à la pièce, sur le compte qu'affiche la ligne" do
      expect(beurre.quantity_edit_unit).to eq("piece")
      expect(beurre.quantity_edit_options).to include([ "plaquette", "piece", 1 ], [ "g", "g", 40 ])
    end

    it "s'ouvre dans l'unité de base sur ce qui ne se compte pas" do
      farine = build(:grocery_item, unit_group: :mass, base_unit: "g", quantity_base: 500)

      expect(farine.quantity_edit_unit).to eq("g")
      expect(farine.quantity_edit_options).to include([ "kg", "kg", 0.5 ])
    end

    it "dit exactement en grammes ce qui se compte en pièces" do
      oignons = build(:grocery_item, unit_group: :count, base_unit: "piece", quantity_base: 2,
                                     piece_label: "oignon", piece_weight_g: 150)

      expect(oignons.quantity_edit_options).to include([ "g", "g", 300 ])
    end

    it "ramène la saisie à l'unité de base" do
      expect(beurre.enter_quantity("2", "piece")).to be(true)
      expect(beurre.quantity_base).to eq(500)
    end

    it "refuse une unité qui ne convient pas à la ligne" do
      expect(beurre.enter_quantity("1", "l")).to be(false)
      expect(beurre.quantity_base).to eq(40)
      expect(beurre.errors[:base]).to include("L'unité « L » ne convient pas à Beurre")
    end
  end

  # L'« Annuler » du message qui suit un ajout additionné à une ligne
  describe "annulation d'un ajout" do
    let(:item) { create(:grocery_item, source: :generated, quantity_base: 100, checked: true) }

    def add(quantity)
      item.add_quantity(quantity)
      item.save!
      item.undo_token
    end

    it "dit la quantité d'avant l'ajout" do
      add(250)

      expect([ item.quantity_before_last_save_display, item.quantity_display ]).to eq([ "100 g", "350 g" ])
    end

    it "remet la ligne dans son état d'avant, coche comprise" do
      token = add(250)

      expect(item.undo!(token)).to be true
      expect(item.reload).to have_attributes(quantity_base: 100, extra_quantity_base: nil,
                                             checked: true, previous_quantity_base: nil)
    end

    # Seul compte ce que l'ajout avait changé
    it "garde ce qu'un autre membre a changé d'autre entre-temps" do
      item.update!(checked: false)
      token = add(250)
      item.update!(checked: true)

      expect(item.undo!(token)).to be true
      expect(item.reload).to have_attributes(quantity_base: 100, checked: true)
    end

    it "refuse quand la quantité a bougé depuis, et dit pourquoi" do
      token = add(250)
      item.update!(quantity_base: 300)

      expect(item.undo!(token)).to be false
      expect(item.reload.quantity_base).to eq(300)
      expect(item.errors.full_messages.to_sentence).to include("a changé depuis")
    end

    it "refuse le jeton d'une autre ligne, ou un jeton forgé" do
      other = create(:grocery_item, menu: item.menu)
      token = add(250)

      expect(other.undo!(token)).to be false
      expect(item.undo!("forgé")).to be false
      expect(item.undo!(nil)).to be false
    end
  end
end
