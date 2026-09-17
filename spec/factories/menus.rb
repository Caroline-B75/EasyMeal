FactoryBot.define do
  factory :menu do
    # Un menu appartient au foyer. `create(:menu, user: user)` le range dans le
    # foyer de ce compte — la façon la plus lisible de dire « un menu que cet
    # utilisateur voit ». Sans `user`, un compte est créé pour l'occasion : un
    # foyer a toujours au moins un membre.
    transient do
      user { association(:user) }
    end

    household { user.household }
    sequence(:name) { |n| "Menu #{n}" }
    diet { :omnivore }
    default_people { 4 }
    status { :draft }
  end
end
