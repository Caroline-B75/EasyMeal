require "rails_helper"

RSpec.describe RecipeImport, type: :model do
  # Le contrôleur formule déjà les refus en langage de formulaire ; ces règles-ci
  # sont la seconde ligne, celle qui tient même si un import est créé ailleurs.
  describe "validations" do
    it "refuse une source qui n'est ni un lien ni une photo" do
      expect(build(:recipe_import, source_type: "fax")).not_to be_valid
    end

    it "exige une URL pour un import par lien" do
      expect(build(:recipe_import, source_url: nil)).not_to be_valid
    end

    it "n'en exige aucune pour un import par photo" do
      expect(build(:recipe_import, :from_photo)).to be_valid
    end
  end

  describe "#finished?" do
    it "n'est vrai qu'une fois l'import abouti ou échoué" do
      expect(build(:recipe_import, status: :pending)).not_to be_finished
      expect(build(:recipe_import, status: :processing)).not_to be_finished
      expect(build(:recipe_import, status: :succeeded)).to be_finished
      expect(build(:recipe_import, status: :failed)).to be_finished
    end
  end

  # Statut et motif s'écrivent ensemble : un import échoué sans motif ne
  # laisserait rien à afficher à l'utilisatrice.
  describe "#fail_with!" do
    it "écrit le statut et le motif d'un seul geste" do
      import = create(:recipe_import)

      import.fail_with!("Extraction échouée : URL inaccessible")

      expect(import.reload).to have_attributes(
        status: "failed", error_message: "Extraction échouée : URL inaccessible"
      )
    end
  end

  describe "#succeed_with!" do
    it "rattache le brouillon obtenu et efface le motif d'un essai précédent" do
      import = create(:recipe_import, status: :failed, error_message: "tentative précédente")
      recipe = create(:recipe, :with_ingredient)

      import.succeed_with!(recipe)

      expect(import.reload).to have_attributes(
        status: "succeeded", recipe: recipe, error_message: nil
      )
    end
  end
end
