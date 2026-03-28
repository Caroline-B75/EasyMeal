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
  end
end
