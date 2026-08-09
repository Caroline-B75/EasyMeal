FactoryBot.define do
  factory :recipe do
    name { "MyString" }
    description { "MyText" }
    instructions { "MyText" }
    default_servings { 1 }
    prep_time_minutes { 1 }
    cook_time_minutes { 1 }
    difficulty { 1 }
    price { 1 }
    diet { 1 }
    appliance { "MyString" }
    source_url { "MyString" }
    # Une recette publiée doit annoncer au moins un moment (UC7) : on reprend le
    # backfill de l'existant, qui reste le cas le plus courant.
    meal_types { %w[lunch dinner] }

    # Recette publiable telle quelle : la validation « au moins un ingrédient »
    # exige que la préparation soit là DÈS la première sauvegarde.
    trait :with_ingredient do
      after(:build) do |recipe|
        recipe.preparations.build(ingredient: create(:ingredient), quantity_base: 100)
      end
    end

    # Recette DE SAISON ce mois-ci : son unique ingrédient l'est (une recette
    # est de saison dès qu'un de ses ingrédients l'est). La factory ingredient
    # ne renseignant pas season_months, :with_ingredient donne le pendant
    # hors saison.
    trait :seasonal do
      after(:build) do |recipe|
        recipe.preparations.build(
          ingredient: create(:ingredient, season_months: [ Date.current.month ]),
          quantity_base: 100
        )
      end
    end
  end
end
