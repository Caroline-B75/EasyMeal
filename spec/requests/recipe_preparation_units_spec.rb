# frozen_string_literal: true

require "rails_helper"

# Champ « quantité » d'un ingrédient dans le formulaire de recette : ce qui se
# saisit (un nombre et une unité) n'est pas ce qui se soumet (quantity_base, en
# unité de base). Le sélecteur d'unité existe pour qu'une unité mal lue — par
# l'IA d'un import, ou par soi-même — se corrige sans refaire la conversion de
# tête.
RSpec.describe "Unités des quantités d'une recette", type: :request do
  let(:admin) { create(:user, admin: true) }

  before { sign_in admin }

  # Une recette portant un ingrédient du groupe d'unités demandé. La préparation
  # est bâtie avant la première sauvegarde : une recette publiée doit annoncer au
  # moins un ingrédient dès sa création.
  def recipe_with(unit_group, base_unit, quantity_base: 9)
    ingredient = create(:ingredient, unit_group: unit_group, base_unit: base_unit)
    recipe = build(:recipe)
    recipe.preparations.build(ingredient: ingredient, quantity_base: quantity_base)
    recipe.save!
    recipe
  end

  it "propose les unités du groupe de l'ingrédient, l'unité de base retenue" do
    get edit_recipe_path(recipe_with(:spoon, "cac"))

    expect(response.body).to include(">càc</option>", ">càs</option>")
    expect(response.body).to match(/<option selected(?:="selected")? value="cac">càc<\/option>/)
  end

  # Les ingrédients comptés en cuillères sont surtout des épices et des poudres :
  # leur proposer des centilitres n'inviterait qu'à se tromper.
  it "ne propose pas de volume à un ingrédient compté en cuillères" do
    get edit_recipe_path(recipe_with(:spoon, "cac"))

    expect(response.body).not_to include(">cl</option>", ">dl</option>")
  end

  # Le cas de l'huile d'olive : comptée en millilitres au catalogue, elle se
  # mesure aussi à la cuillère dans les recettes.
  it "propose les cuillères à un ingrédient compté en millilitres" do
    get edit_recipe_path(recipe_with(:volume, "ml", quantity_base: 45))

    expect(response.body).to include(">ml</option>", ">cl</option>", ">L</option>",
                                     ">càc</option>", ">càs</option>")
    expect(response.body).to match(/<option selected(?:="selected")? value="ml">ml<\/option>/)
  end

  # Un seul choix possible : le sélecteur se lit alors comme le simple suffixe
  # qu'il était avant d'être un champ.
  it "rend le sélecteur inerte quand le groupe n'offre qu'une unité" do
    get edit_recipe_path(recipe_with(:count, "piece"))

    expect(response.body).to match(/<select[^>]*rf-unit-select[^>]*disabled/)
    expect(response.body).to include(">pièce</option>")
    expect(response.body).not_to include(">càs</option>")
  end

  # La quantité soumise est celle du champ caché ; le nombre visible, lui, ne
  # porte aucun nom — il n'est là que pour être lu et corrigé, et c'est le
  # contrôleur Stimulus qui en dérive la quantité de base.
  it "soumet la quantité de base dans un champ caché, à côté du nombre affiché" do
    get edit_recipe_path(recipe_with(:spoon, "cac", quantity_base: 9))

    # La dernière ligne rendue, la première étant le gabarit des nouvelles lignes
    hidden  = response.body.scan(/<input[^>]*ingredient-unit-target="base"[^>]*>/).last
    visible = response.body.scan(/<input[^>]*ingredient-unit-target="quantity"[^>]*>/).last

    expect(hidden).to include('type="hidden"', 'value="9.0"', "[0][quantity_base]")
    expect(visible).to include('value="9.0"')
    expect(visible).not_to include("name=")
  end

  # C'est de là que le contrôleur Stimulus tire les unités à proposer quand on
  # change d'ingrédient en cours de saisie.
  it "annonce le groupe d'unités de chaque ingrédient du sélecteur" do
    get edit_recipe_path(recipe_with(:spoon, "cac"))

    expect(response.body).to match(/<option[^>]*data-unit="cac"[^>]*data-unit-group="spoon"/)
  end
end
