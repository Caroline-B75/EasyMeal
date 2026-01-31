FactoryBot.define do
  factory :review do
    user { nil }
    recipe { nil }
    rating { 1 }
    content { "MyText" }
  end
end
