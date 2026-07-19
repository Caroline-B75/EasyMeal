# Seed principal : utilisateur admin + données de référence (ingrédients, tags,
# recettes de démonstration). Idempotent et exécuté dans une transaction unique
# (tout ou rien) pour éviter un état partiel en cas d'erreur.

ActiveRecord::Base.transaction do
  puts "👤 Utilisateur admin..."

  # Identifiants configurables par l'environnement : jamais de secret réel dans le dépôt.
  # En développement/test, mot de passe par défaut évident ; en production, ENV obligatoire.
  admin_email    = ENV.fetch("SEED_ADMIN_EMAIL", "caroline.belmas@gmail.com")
  admin_password = ENV.fetch("SEED_ADMIN_PASSWORD") do
    raise "SEED_ADMIN_PASSWORD est requis en production" if Rails.env.production?

    "password" # valeur de développement uniquement
  end

  admin = User.find_or_initialize_by(email: admin_email)
  if admin.new_record?
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
