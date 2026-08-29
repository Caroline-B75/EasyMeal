# frozen_string_literal: true

require "rails_helper"

# Zone photo du formulaire de recette : le fichier peut arriver par clic, par
# glisser-déposer ou par collage d'une capture d'écran. Les gestes vivent dans
# le contrôleur Stimulus — côté requêtes, seul leur branchement est vérifiable,
# et c'est lui qui saute si la vue change.
RSpec.describe "Zone photo du formulaire de recette", type: :request do
  let(:admin) { create(:user, admin: true) }

  before { sign_in admin }

  it "câble le dépôt de fichier et le collage sur le formulaire de création" do
    get new_recipe_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("drop-&gt;image-preview#dropFile")
    expect(response.body).to include("paste@document-&gt;image-preview#paste")
  end

  it "rend l'aperçu du fichier choisi, masqué tant qu'aucun fichier n'est choisi" do
    get new_recipe_path

    expect(response.body).to include("photo-preview--chosen")
  end

  it "câble les mêmes gestes à l'édition d'une recette existante" do
    get edit_recipe_path(create(:recipe, :with_ingredient))

    expect(response.body).to include("drop-&gt;image-preview#dropFile")
    expect(response.body).to include("paste@document-&gt;image-preview#paste")
  end
end
