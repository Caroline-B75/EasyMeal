require "rails_helper"

RSpec.describe RecipesHelper, type: :helper do
  # La vignette d'une recette se fabrique par URL de transformation Cloudinary,
  # jamais par ActiveStorage .variant() : une variante exigerait libvips installé
  # sur le serveur et réuploaderait une image dérivée à chaque nouvelle photo.
  # Les exemples ci-dessous verrouillent ce choix — c'est la régression qui
  # casserait les images en production.
  describe "#recipe_photo_tag" do
    context "quand la recette a une photo" do
      let(:recipe) { create(:recipe, :with_ingredient, :with_photo, name: "Tarte aux poireaux") }

      it "sert une URL Cloudinary et non une variante ActiveStorage" do
        html = helper.recipe_photo_tag(recipe, width: 280, height: 140)

        expect(html).to include("res.cloudinary.com")
        expect(html).not_to include("active_storage")
      end

      it "recadre exactement aux dimensions demandées" do
        html = helper.recipe_photo_tag(recipe, width: 280, height: 140)

        expect(html).to include("c_fill", "w_280", "h_140")
      end

      it "double la définition dans le srcset pour les écrans à forte densité" do
        html = helper.recipe_photo_tag(recipe, width: 280, height: 140)

        expect(html).to include("srcset")
        expect(html).to include("w_560", "h_280")
      end
    end

    context "quand la recette n'a pas de photo" do
      let(:recipe) { create(:recipe, :with_ingredient, name: "Soupe de potiron") }

      it "retombe sur l'image par défaut du projet" do
        html = helper.recipe_photo_tag(recipe, width: 96, height: 48)

        expect(html).to include("photo_par_defaut_recette")
        expect(html).not_to include("res.cloudinary.com")
      end

      it "ne pose aucun srcset : l'image par défaut n'a qu'une définition" do
        expect(helper.recipe_photo_tag(recipe, width: 96, height: 48)).not_to include("srcset")
      end
    end

    # Attributs communs aux deux branches : la boîte est réservée avant le
    # chargement (width/height) et le nom de la recette sert de texte alternatif.
    describe "attributs de la balise" do
      let(:recipe) { create(:recipe, :with_ingredient, name: "Gratin dauphinois") }

      it "réserve la place et décrit l'image" do
        html = helper.recipe_photo_tag(recipe, width: 192, height: 96)

        expect(html).to include('width="192"', 'height="96"')
        expect(html).to include('alt="Gratin dauphinois"')
        expect(html).to include('loading="lazy"')
      end

      it "n'ajoute une classe que si l'appelant en fournit une" do
        expect(helper.recipe_photo_tag(recipe, width: 192, height: 96)).not_to include("class=")

        classed = helper.recipe_photo_tag(recipe, width: 192, height: 96, css_class: "mi-hist-recipe-photo")
        expect(classed).to include('class="mi-hist-recipe-photo"')
      end
    end
  end
end
