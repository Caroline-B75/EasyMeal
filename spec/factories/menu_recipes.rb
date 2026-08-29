FactoryBot.define do
  factory :menu_recipe do
    association :menu
    association :recipe
    number_of_people { 4 }
  end
end
