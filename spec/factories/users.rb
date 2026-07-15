FactoryBot.define do
  factory :user do
    sequence(:email) { |n| "user#{n}@example.com" }
    sequence(:username) { |n| "user#{n}" }
    first_name { "Test" }
    last_name { "User" }
    gender { "female" }
    default_diet { :omnivore }
    default_people { 2 }
    password { "password123" }
  end
end
