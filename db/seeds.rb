# Seed for the first admin user
puts "Creating admin user..."

admin_email = "caroline.belmas@gmail.com"
admin_password = "5750dena"

admin = User.find_or_initialize_by(email: admin_email)
admin.update!(
  username: "Caro",
  first_name: "Caroline",
  last_name: "Belmas",
  password: admin_password,
  password_confirmation: admin_password,
  admin: true
)

puts "Admin user created: #{admin.email}"

# Charger les ingrédients
puts "\n🌱 Chargement des ingrédients..."
load Rails.root.join('db', 'seeds', 'ingredients.rb')

# Charger les tags
puts "\n🏷️ Chargement des tags..."
load Rails.root.join('db', 'seeds', 'tags.rb')

# Charger les recettes de test
puts "\n🍽️ Chargement des recettes..."
load Rails.root.join('db', 'seeds', 'recipes.rb')

puts "\n✅ Seed terminée!"
