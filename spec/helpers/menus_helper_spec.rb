require "rails_helper"

RSpec.describe MenusHelper, type: :helper do
  # Les libellés de régime vivent dans config/locales/fr.yml : ces exemples
  # vérifient le chemin de lecture (I18n) et, surtout, les replis — une
  # étiquette décorative ne doit jamais faire tomber une page.
  describe "#menu_diet_label" do
    it "traduit les quatre régimes de l'enum" do
      expect(helper.menu_diet_label("omnivore")).to eq("Omnivore")
      expect(helper.menu_diet_label("vegetarien")).to eq("Végétarien")
      expect(helper.menu_diet_label("vegan")).to eq("Vegan")
      expect(helper.menu_diet_label("pescetarien")).to eq("Pescétarien")
    end

    it "accepte un symbole aussi bien qu'une chaîne" do
      expect(helper.menu_diet_label(:vegan)).to eq("Vegan")
    end

    it "retombe sur la clé humanisée pour un régime inconnu" do
      expect(helper.menu_diet_label("flexitarien")).to eq("Flexitarien")
    end

    it "retourne une chaîne vide quand aucun régime n'est fourni" do
      expect(helper.menu_diet_label(nil)).to eq("")
    end
  end

  describe "#menu_diet_description" do
    it "décrit les quatre régimes de l'enum" do
      expect(helper.menu_diet_description("omnivore")).to eq("Toutes les recettes disponibles")
      expect(helper.menu_diet_description("vegetarien")).to eq("Sans viande ni poisson")
      expect(helper.menu_diet_description("vegan")).to eq("Sans produits d'origine animale")
      expect(helper.menu_diet_description("pescetarien")).to eq("Végétarien + poisson")
    end

    it "retourne une chaîne vide pour un régime inconnu" do
      expect(helper.menu_diet_description("flexitarien")).to eq("")
    end

    it "retourne une chaîne vide quand aucun régime n'est fourni" do
      expect(helper.menu_diet_description(nil)).to eq("")
    end
  end

  # Toutes les clés d'enum doivent être traduites : un régime ajouté au modèle
  # sans sa traduction s'afficherait humanisé et sans description.
  it "couvre toutes les clés de l'enum Menu.diets" do
    Menu.diets.keys.each do |diet|
      expect(I18n.exists?("diets.#{diet}")).to be(true), "traduction manquante : diets.#{diet}"
      expect(helper.menu_diet_description(diet)).to be_present
    end
  end
end
