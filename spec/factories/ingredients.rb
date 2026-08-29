FactoryBot.define do
  factory :ingredient do
    sequence(:name) { |n| "Ingrédient #{n}" }
    category { :epicerie_salee }
    unit_group { :mass }
    base_unit { "g" }
  end
end
