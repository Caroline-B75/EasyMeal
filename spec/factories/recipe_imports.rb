FactoryBot.define do
  factory :recipe_import do
    user
    source_type { "url" }
    source_url  { "https://exemple.fr/tarte" }

    # Import par photo : le contenu du fichier n'a aucune importance, seul son
    # transfert vers le brouillon est en jeu.
    trait :from_photo do
      source_type { "photo" }
      source_url  { nil }

      after(:build) do |import|
        import.source_photo.attach(
          io: StringIO.new("page de magazine"),
          filename: "magazine.jpg",
          content_type: "image/jpeg"
        )
      end
    end
  end
end
