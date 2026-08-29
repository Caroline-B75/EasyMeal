require "rails_helper"

# Le parcours nominal de l'import est vérifié de bout en bout dans
# spec/requests/recipe_imports_spec.rb. Ce fichier-ci ne garde que ce qu'une
# requête ne peut pas atteindre : les issues de secours du job.
RSpec.describe Recipes::ImportJob, type: :job do
  # Filet de sécurité : un bug ne doit pas laisser la page d'attente revenir
  # indéfiniment. L'import est clos avec un message honnête, et l'erreur remonte
  # quand même pour être vue (GoodJob la consigne dans sa propre table).
  it "clôt l'import puis laisse remonter une erreur inattendue" do
    import = create(:recipe_import)
    allow(Recipes::ExtractorService).to receive(:from_url).and_raise(ArgumentError, "bug")

    expect { described_class.perform_now(import) }.to raise_error(ArgumentError)

    expect(import.reload).to have_attributes(
      status: "failed", error_message: "Une erreur inattendue a interrompu l'import."
    )
  end

  # Un import abouti ne se refait pas : ce serait un second appel à l'IA,
  # facturé, pour un résultat déjà obtenu.
  it "ne rejoue pas un import déjà terminé" do
    import = create(:recipe_import, status: :succeeded)
    expect(Recipes::ExtractorService).not_to receive(:from_url)

    described_class.perform_now(import)

    expect(import.reload.status).to eq("succeeded")
  end

  # Le job relit la photo bien après la fin de la requête : si elle a disparu
  # entre-temps, il vaut mieux le dire que d'interroger l'IA à vide.
  it "signale une photo de source introuvable" do
    import = create(:recipe_import, :from_photo)
    import.source_photo.purge

    described_class.perform_now(import)

    expect(import.reload.status).to eq("failed")
    expect(import.error_message).to include("photo de l'import est introuvable")
  end

  # Une extraction qui ne rend rien d'exploitable ne doit pas écrire un brouillon
  # à moitié : le nom manquant fait échouer la validation, et le motif remonte.
  it "rapporte l'échec de validation du brouillon" do
    import = create(:recipe_import)
    allow(Recipes::ExtractorService).to receive(:from_url).and_return("diet" => "inconnu")
    allow_any_instance_of(Recipe).to receive(:save).and_return(false)

    described_class.perform_now(import)

    expect(import.reload.status).to eq("failed")
    expect(import.error_message).to start_with("Impossible de créer le brouillon")
  end

  # « 1 c. à s. de farine » ne se pèse pas sans la densité de la farine. Le job
  # lance l'estimation de celles qui manquent avant de rendre la main : elle
  # arrive ainsi pendant que l'utilisatrice rejoint la page de revue.
  it "lance l'estimation des densités qui manquent au brouillon" do
    farine = create(:ingredient, name: "Farine", unit_group: :mass, base_unit: "g")
    import = create(:recipe_import)
    allow(Recipes::ExtractorService).to receive(:from_url).and_return(
      "name" => "Crêpes", "instructions" => "Mélanger.",
      "ingredients" => [ { "name" => "farine", "quantity" => 2, "unit" => "cas" } ]
    )

    expect { described_class.perform_now(import) }
      .to have_enqueued_job(Ingredients::EstimateDensityJob).with(farine)

    expect(import.reload.status).to eq("succeeded")
  end
end
