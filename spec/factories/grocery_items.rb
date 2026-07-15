FactoryBot.define do
  factory :grocery_item do
    association :menu
    association :ingredient
    sequence(:name) { |n| "Article #{n}" }
    quantity_base { 100 }
    base_unit { "g" }
    category { :epicerie_salee }
    source { :generated }
    checked { false }
  end
end
