# Seed principal : utilisateur admin + données de référence (ingrédients, tags,
# recettes de démonstration). Idempotent et exécuté dans une transaction unique
# (tout ou rien) pour éviter un état partiel en cas d'erreur.

ActiveRecord::Base.transaction do
  puts "👤 Utilisateur admin..."

  # Identifiants configurables par l'environnement : jamais de secret réel dans le dépôt.
  admin_email = ENV.fetch("SEED_ADMIN_EMAIL", "caroline.belmas@gmail.com")

  # Le mot de passe n'est lu que si l'admin doit être créé — c'est-à-dire une
  # seule fois dans la vie d'une base. Le réclamer à chaque passage obligerait à
  # retaper en production un secret qui ne sert plus à rien (le mot de passe d'un
  # admin existant n'est jamais réécrit ci-dessous), et laisserait croire qu'on
  # le change alors qu'il est ignoré. Pour le modifier ensuite : « Mot de passe
  # oublié ? » sur la page de connexion, ou /users/edit une fois connecté.
  # En développement, un mot de passe évident suffit ; en production, ENV est obligatoire.
  read_password = lambda do
    ENV.fetch("SEED_ADMIN_PASSWORD") do
      raise "SEED_ADMIN_PASSWORD est requis en production" if Rails.env.production?

      "password" # valeur de développement uniquement
    end
  end

  admin = User.find_or_initialize_by(email: admin_email)
  if admin.new_record?
    admin_password = read_password.call
    admin.assign_attributes(
      username: "Caro",
      first_name: "Caroline",
      last_name: "Belmas",
      password: admin_password,
      password_confirmation: admin_password,
      admin: true
    )
    admin.save!
    puts "  ✅ Admin créé : #{admin.email}"
  else
    # Ne jamais réécrire le mot de passe d'un admin existant au re-seed ;
    # on garantit seulement le rôle admin.
    admin.update!(admin: true) unless admin.admin?
    puts "  ✅ Admin existant conservé : #{admin.email}"
  end

  puts "\n🌱 Ingrédients..."
  load Rails.root.join("db/seeds/ingredients.rb").to_s

  puts "\n🏷️  Tags..."
  load Rails.root.join("db/seeds/tags.rb").to_s

  puts "\n📖 Recettes..."
  load Rails.root.join("db/seeds/recipes.rb").to_s
end

puts "\n✅ Seed terminée !"
