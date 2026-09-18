FactoryBot.define do
  factory :usual_grocery_item do
    # Un compte naît avec son foyer : c'est le moyen le plus court d'en avoir un
    household { association(:user).household }
    sequence(:name) { |n| "Course habituelle #{n}" }
    quantity { 1 }
    unit { "piece" }
    category { :hygiene_beaute }
  end
end
