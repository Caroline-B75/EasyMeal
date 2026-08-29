# frozen_string_literal: true

require "rails_helper"

# Sélecteur d'ingrédient du formulaire de recette. Deux exigences qui tirent en
# sens contraire : montrer l'unité attendue avant qu'on choisisse, et ne pas
# servir le catalogue entier autant de fois qu'il y a de lignes.
RSpec.describe "Sélecteur d'ingrédient d'une recette", type: :request do
  let(:admin) { create(:user, admin: true) }

  before { sign_in admin }

  def recipe_with(*ingredients)
    recipe = build(:recipe)
    ingredients.each { |ingredient| recipe.preparations.build(ingredient: ingredient, quantity_base: 100) }
    recipe.save!
    recipe
  end

  it "écrit l'unité de l'ingrédient dans le libellé de son option" do
    oeuf = create(:ingredient, name: "Œuf", unit_group: :count, base_unit: "piece", aliases: [ "oeufs" ])

    get edit_recipe_path(recipe_with(oeuf))

    expect(response.body).to include("Œuf (oeufs) — pièce")
  end

  # Le cœur de l'affaire : le catalogue n'est rendu qu'une fois, dans le modèle
  # de ligne. Sans ça, chaque ligne d'une recette en portait une copie — à près
  # de 600 ingrédients, un demi-méga de HTML pour une recette ordinaire.
  it "ne sert le catalogue qu'une seule fois, quel que soit le nombre de lignes" do
    ingredients = Array.new(3) { |i| create(:ingredient, name: "Ingrédient #{i}") }
    create(:ingredient, name: "Cannelle", unit_group: :spoon, base_unit: "cac")

    get edit_recipe_path(recipe_with(*ingredients))

    # « Cannelle » n'appartient à aucune ligne : il n'apparaît donc que dans le
    # modèle de ligne, une fois — et non trois, une par ligne remplie.
    expect(response.body.scan(/Cannelle — càc/).size).to eq(1)
  end

  it "garde dans chaque ligne l'ingrédient qu'elle a déjà, sélectionné" do
    sel = create(:ingredient, name: "Basilic frais")

    get edit_recipe_path(recipe_with(sel))

    expect(response.body).to match(/selected value="#{sel.id}"/)
  end

  # Les lignes allégées réclament leur complément ; le modèle de ligne, qui
  # porte déjà tout, ne doit pas se le faire ajouter une seconde fois.
  it "ne branche le complément que sur les lignes allégées" do
    get edit_recipe_path(recipe_with(create(:ingredient)))

    expect(response.body.scan(/data-controller="ingredient-options"/).size).to eq(1)
  end
end
