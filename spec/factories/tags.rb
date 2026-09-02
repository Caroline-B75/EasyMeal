FactoryBot.define do
  factory :tag do
    name { "MyString" }
    # Rubrique par défaut : « Autre », celle qui n'engage rien. Les specs qui
    # testent le regroupement par rubrique nomment le type dont elles ont besoin.
    tag_type { :autre }
  end
end
