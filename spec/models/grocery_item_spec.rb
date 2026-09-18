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

  # Courses habituelles (UC8, étape 3) : une ligne additionne sa part (menu ou
  # ajout ponctuel) et sa part habituelle.
  describe "part habituelle" do
    # 500 ml pour une recette, 6 L d'habitude
    def mixed_line(**attributes)
      create(:grocery_item, base_unit: "ml", quantity_base: 6500, usual_quantity_base: 6000, **attributes)
    end

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

        expect(item).to have_attributes(quantity_base: 6500, usual_quantity_base: 6000)
      end
    end

    # La part du menu est recalculée à chaque validation : une correction à la
    # main porte sur la part habituelle.
    describe "#shift_quantity_change_to_usual_part" do
      def correct(item, quantity)
        item.quantity_base = quantity
        item.shift_quantity_change_to_usual_part
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

      it "ne touche pas une ligne sans part habituelle" do
        expect(correct(create(:grocery_item, quantity_base: 100), 80).usual_quantity_base).to be_nil
      end
    end
  end
end
