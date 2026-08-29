# frozen_string_literal: true

require "rails_helper"

# UC5 : le catalogue de recettes assemblé pour RecipesController#index.
# Le filtrage est déjà couvert par filter_service_spec — ici on vérifie ce que
# cet objet ajoute : la page paginée, les tags de la sidebar, et surtout les
# précalculs qui évitent les N+1 (favoris et recettes de saison en UNE requête).
RSpec.describe Recipes::CatalogQuery do
  # Paginateur factice : le vrai vient du contrôleur (Pagy::Backend). On vérifie
  # qu'il reçoit bien la relation filtrée et que son objet pagy est reconduit.
  let(:paginator) { ->(relation) { [ :pagy_object, relation ] } }

  def catalog(params = {}, user: nil)
    described_class.call(scope: Recipe.all,
                         params: ActionController::Parameters.new(params),
                         user: user,
                         &paginator)
  end

  describe "page de résultats" do
    let!(:tarte)  { create(:recipe, :with_ingredient, name: "Tarte",  diet: :vegetarien) }
    let!(:burger) { create(:recipe, :with_ingredient, name: "Burger", diet: :omnivore) }

    it "délègue le filtrage à FilterService" do
      expect(catalog({ diet: "vegetarien" }).recipes).to contain_exactly(tarte)
    end

    it "trie par nom en l'absence de paramètre de tri" do
      expect(catalog.recipes.map(&:name)).to eq([ "Burger", "Tarte" ])
    end

    it "honore le paramètre de tri" do
      expect(catalog({ sort: "name desc" }).recipes).to eq([ tarte, burger ])
    end

    it "reconduit l'objet pagy renvoyé par le paginateur" do
      expect(catalog.pagy).to eq(:pagy_object)
    end
  end

  describe "tags de la sidebar" do
    let!(:used)   { create(:tag, name: "Rapide") }
    let!(:unused) { create(:tag, name: "Orphelin") }

    before { create(:recipe, :with_ingredient, tags: [ used ]) }

    it "ne retient que les tags portés par au moins une recette" do
      expect(catalog.tags).to contain_exactly(used)
    end
  end

  describe "favoris" do
    let(:user)    { create(:user) }
    let!(:liked)  { create(:recipe, :with_ingredient, name: "Aimée") }
    let!(:other)  { create(:recipe, :with_ingredient, name: "Boudée") }

    before do
      create(:favorite_recipe, user: user, recipe: liked)
      create(:favorite_recipe, user: create(:user), recipe: other)
    end

    it "ne marque que les favoris de l'utilisateur passé" do
      result = catalog({}, user: user)

      expect(result).to be_favorited(liked)
      expect(result).not_to be_favorited(other)
    end

    it "ne marque aucun favori pour un visiteur anonyme" do
      expect(catalog.favorited_ids).to be_empty
    end
  end

  describe "recettes de saison" do
    let!(:in_season)  { create(:recipe, :seasonal, name: "De saison") }
    let!(:off_season) { create(:recipe, :with_ingredient, name: "Hors saison") }

    it "expose le mois courant, qui sert aussi de clé de cache aux cartes" do
      expect(catalog.current_month).to eq(Date.current.month)
    end

    it "ne marque que les recettes de saison ce mois-ci" do
      result = catalog

      expect(result).to be_seasonal(in_season)
      expect(result).not_to be_seasonal(off_season)
    end

    it "précalcule l'appartenance en une seule requête, quel que soit le nombre de cartes" do
      create_list(:recipe, 3, :seasonal)

      expect(count_queries(/season_months/) { catalog }).to eq(1)
    end

    it "n'interroge pas la base quand la page est vide" do
      expect(count_queries(/season_months/) { catalog({ query: "aucun-resultat-possible" }) }).to eq(0)
    end
  end

  # Compte les requêtes SQL émises pendant le bloc et correspondant au motif :
  # garde-fou sur les précalculs anti-N+1 du catalogue.
  def count_queries(pattern)
    count = 0
    subscriber = ActiveSupport::Notifications.subscribe("sql.active_record") do |*, payload|
      count += 1 if payload[:sql].match?(pattern)
    end
    yield
    count
  ensure
    ActiveSupport::Notifications.unsubscribe(subscriber)
  end
end
