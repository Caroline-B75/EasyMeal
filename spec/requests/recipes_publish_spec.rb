# frozen_string_literal: true

require "rails_helper"

# Publication d'un brouillon importé : ce que devient le formulaire quand la
# sauvegarde n'aboutit pas.
#
# Le brouillon ne porte rien en base tant qu'on n'a pas publié — sa liste
# d'ingrédients se compose dans la page, depuis le panneau d'import. Un échec
# doit donc rendre la saisie telle qu'elle est partie, et dire quoi corriger :
# une page d'erreur muette, c'est le travail à refaire depuis l'import.
RSpec.describe "Publication d'un brouillon de recette", type: :request do
  let(:admin) { create(:user, admin: true) }
  let(:sauce_soja) { create(:ingredient, name: "Sauce soja") }
  let(:tofu) { create(:ingredient, name: "Tofu ferme") }
  let(:draft) { create(:recipe, status: :draft, ai_raw_data: { "ingredients" => [] }) }

  before { sign_in admin }

  # Le formulaire tel que le navigateur le soumet : une entrée par ligne
  # d'ingrédient, indexée comme le fait nested-form.
  def publish(*lines)
    preparations = lines.each_with_index.to_h do |(ingredient, quantity), index|
      [ index.to_s, { ingredient_id: ingredient.id, quantity_base: quantity, _destroy: "false" } ]
    end

    patch recipe_path(draft), params: {
      _publish: "1",
      recipe: { name: "Bowl au tofu satay", diet: "vegan", default_servings: 2,
                meal_types: %w[lunch dinner], instructions: "Faire revenir le tofu.",
                preparations_attributes: preparations }
    }
  end

  it "publie la recette quand la liste est saine" do
    publish([ sauce_soja, 5 ], [ tofu, 200 ])

    expect(response).to redirect_to(recipe_path(draft))
    expect(draft.reload).to be_published
    expect(draft.preparations.count).to eq(2)
  end

  # Le cas vécu en production : la recette d'origine citait la sauce soja deux
  # fois, le panneau d'import avait posé deux lignes, et l'insertion se heurtait
  # à l'index d'unicité en pleine publication — 500 sans un mot.
  describe "deux lignes pour le même ingrédient" do
    before { publish([ sauce_soja, 5 ], [ tofu, 200 ], [ sauce_soja, 2 ]) }

    it "refuse la publication au lieu de laisser Postgres la faire échouer" do
      expect(response).to have_http_status(:unprocessable_entity)
      expect(draft.reload).to be_draft
    end

    it "nomme l'ingrédient en double et dit quoi en faire" do
      expect(response.body).to include("Sauce soja apparaît plusieurs fois dans la liste des ingrédients")
      expect(response.body).to include("garde une seule ligne par ingrédient, en additionnant les quantités")
    end

    it "rend le formulaire avec la saisie intacte — rien n'est à ressaisir" do
      expect(response.body).to include("Bowl au tofu satay")
      expect(response.body).to include("Faire revenir le tofu.")
      # Les trois lignes soumises sont toujours là, celle en trop comprise :
      # c'est à l'utilisatrice de choisir laquelle garder.
      expect(response.body.scan(/name="recipe\[preparations_attributes\]\[\d+\]\[ingredient_id\]"/).size).to eq(3)
    end
  end

  # Filet de sécurité du contrôleur : la validation ne voit pas ce qu'un autre
  # onglet vient d'enregistrer, et c'est alors l'index qui refuse, en pleine
  # sauvegarde. Le formulaire doit survivre à ce refus-là aussi.
  it "rattrape un refus de l'index d'unicité sans page d'erreur" do
    allow_any_instance_of(Recipe).to receive(:update).and_raise(ActiveRecord::RecordNotUnique)

    publish([ sauce_soja, 5 ])

    expect(response).to have_http_status(:unprocessable_entity)
    # L'apostrophe du message ressort échappée du rendu HAML.
    expect(response.body).to include("enregistrement a échoué")
    expect(response.body).to include("garde une seule ligne par ingrédient, en additionnant les quantités")
  end
end
