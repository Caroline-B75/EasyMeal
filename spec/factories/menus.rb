FactoryBot.define do
  factory :menu do
    association :user
    sequence(:name) { |n| "Menu #{n}" }
    diet { :omnivore }
    default_people { 4 }
    status { :draft }
  end
end
