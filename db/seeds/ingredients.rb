# Seed pour les ingrédients de base français
# ~180 ingrédients courants pour cuisiner des recettes salées et sucrées

puts "🌱 Création des ingrédients de base..."

# ============================================
# FRUITS ET LÉGUMES (fruits_legumes)
# ============================================
puts "  → Fruits et légumes..."

[
  { name: "Tomate", category: :fruits_legumes, unit_group: :mass, base_unit: "g", season_months: [6, 7, 8, 9], aliases: ["tomate ronde", "tomate grappe"] },
  { name: "Tomate cerise", category: :fruits_legumes, unit_group: :mass, base_unit: "g", season_months: [6, 7, 8, 9], aliases: [] },
  { name: "Carotte", category: :fruits_legumes, unit_group: :mass, base_unit: "g", season_months: [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12], aliases: ["carottes"] },
  { name: "Pomme de terre", category: :fruits_legumes, unit_group: :mass, base_unit: "g", season_months: [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12], aliases: ["pommes de terre", "patate"] },
  { name: "Oignon", category: :fruits_legumes, unit_group: :count, base_unit: "piece", season_months: [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12], aliases: ["oignons"] },
  { name: "Oignon rouge", category: :fruits_legumes, unit_group: :count, base_unit: "piece", season_months: [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12], aliases: [] },
  { name: "Échalote", category: :fruits_legumes, unit_group: :count, base_unit: "piece", season_months: [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12], aliases: ["échalotes"] },
  { name: "Ail", category: :fruits_legumes, unit_group: :count, base_unit: "piece", season_months: [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12], aliases: ["gousse d'ail"] },
  { name: "Courgette", category: :fruits_legumes, unit_group: :mass, base_unit: "g", season_months: [5, 6, 7, 8, 9], aliases: ["courgettes"] },
  { name: "Aubergine", category: :fruits_legumes, unit_group: :mass, base_unit: "g", season_months: [6, 7, 8, 9], aliases: ["aubergines"] },
  { name: "Poivron rouge", category: :fruits_legumes, unit_group: :count, base_unit: "piece", season_months: [6, 7, 8, 9], aliases: [] },
  { name: "Poivron vert", category: :fruits_legumes, unit_group: :count, base_unit: "piece", season_months: [6, 7, 8, 9], aliases: [] },
  { name: "Poivron jaune", category: :fruits_legumes, unit_group: :count, base_unit: "piece", season_months: [6, 7, 8, 9], aliases: [] },
  { name: "Salade verte", category: :fruits_legumes, unit_group: :count, base_unit: "piece", season_months: [4, 5, 6, 7, 8, 9], aliases: ["laitue"] },
  { name: "Épinards", category: :fruits_legumes, unit_group: :mass, base_unit: "g", season_months: [1, 2, 3, 4, 10, 11, 12], aliases: ["épinard"] },
  { name: "Haricots verts", category: :fruits_legumes, unit_group: :mass, base_unit: "g", season_months: [6, 7, 8, 9], aliases: ["haricot vert"] },
  { name: "Brocoli", category: :fruits_legumes, unit_group: :mass, base_unit: "g", season_months: [1, 2, 3, 10, 11, 12], aliases: ["brocolis"] },
  { name: "Chou-fleur", category: :fruits_legumes, unit_group: :mass, base_unit: "g", season_months: [1, 2, 3, 10, 11, 12], aliases: [] },
  { name: "Champignon de Paris", category: :fruits_legumes, unit_group: :mass, base_unit: "g", season_months: [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12], aliases: ["champignons de Paris"] },
  { name: "Champignon", category: :fruits_legumes, unit_group: :mass, base_unit: "g", season_months: [9, 10, 11], aliases: ["champignons"] },
  { name: "Pomme", category: :fruits_legumes, unit_group: :count, base_unit: "piece", season_months: [8, 9, 10, 11], aliases: ["pommes"] },
  { name: "Poire", category: :fruits_legumes, unit_group: :count, base_unit: "piece", season_months: [8, 9, 10, 11], aliases: ["poires"] },
  { name: "Banane", category: :fruits_legumes, unit_group: :count, base_unit: "piece", season_months: [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12], aliases: ["bananes"] },
  { name: "Orange", category: :fruits_legumes, unit_group: :count, base_unit: "piece", season_months: [12, 1, 2, 3], aliases: ["oranges"] },
  { name: "Citron", category: :fruits_legumes, unit_group: :count, base_unit: "piece", season_months: [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12], aliases: ["citrons"] },
  { name: "Citron vert", category: :fruits_legumes, unit_group: :count, base_unit: "piece", season_months: [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12], aliases: ["lime"] },
  { name: "Fraise", category: :fruits_legumes, unit_group: :mass, base_unit: "g", season_months: [5, 6, 7], aliases: ["fraises"] },
  { name: "Framboise", category: :fruits_legumes, unit_group: :mass, base_unit: "g", season_months: [6, 7, 8], aliases: ["framboises"] },
  { name: "Avocat", category: :fruits_legumes, unit_group: :count, base_unit: "piece", season_months: [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12], aliases: ["avocats"] },
  { name: "Concombre", category: :fruits_legumes, unit_group: :count, base_unit: "piece", season_months: [5, 6, 7, 8], aliases: ["concombres"] },
].each { |attrs| Ingredient.create!(attrs) }

# ============================================
# BOUCHERIE / VIANDE (boucherie_viande)
# ============================================
puts "  → Boucherie / Viande..."

[
  { name: "Bœuf haché", category: :boucherie_viande, unit_group: :mass, base_unit: "g", season_months: [], aliases: ["viande hachée de bœuf"] },
  { name: "Steak de bœuf", category: :boucherie_viande, unit_group: :mass, base_unit: "g", season_months: [], aliases: ["steaks de bœuf"] },
  { name: "Rôti de bœuf", category: :boucherie_viande, unit_group: :mass, base_unit: "g", season_months: [], aliases: [] },
  { name: "Poulet entier", category: :boucherie_viande, unit_group: :mass, base_unit: "g", season_months: [], aliases: [] },
  { name: "Blanc de poulet", category: :boucherie_viande, unit_group: :mass, base_unit: "g", season_months: [], aliases: ["filet de poulet", "escalope de poulet"] },
  { name: "Cuisse de poulet", category: :boucherie_viande, unit_group: :mass, base_unit: "g", season_months: [], aliases: ["cuisses de poulet"] },
  { name: "Porc haché", category: :boucherie_viande, unit_group: :mass, base_unit: "g", season_months: [], aliases: [] },
  { name: "Côte de porc", category: :boucherie_viande, unit_group: :mass, base_unit: "g", season_months: [], aliases: ["côtes de porc"] },
  { name: "Rôti de porc", category: :boucherie_viande, unit_group: :mass, base_unit: "g", season_months: [], aliases: [] },
  { name: "Agneau", category: :boucherie_viande, unit_group: :mass, base_unit: "g", season_months: [], aliases: ["gigot d'agneau"] },
  { name: "Veau", category: :boucherie_viande, unit_group: :mass, base_unit: "g", season_months: [], aliases: ["escalope de veau"] },
  { name: "Dinde", category: :boucherie_viande, unit_group: :mass, base_unit: "g", season_months: [], aliases: ["escalope de dinde", "blanc de dinde"] },
].each { |attrs| Ingredient.create!(attrs) }

# ============================================
# CHARCUTERIE / TRAITEUR (charcuterie_traiteur)
# ============================================
puts "  → Charcuterie / Traiteur..."

[
  { name: "Jambon blanc", category: :charcuterie_traiteur, unit_group: :mass, base_unit: "g", season_months: [], aliases: ["jambon cuit"] },
  { name: "Jambon cru", category: :charcuterie_traiteur, unit_group: :mass, base_unit: "g", season_months: [], aliases: ["jambon sec"] },
  { name: "Lardons", category: :charcuterie_traiteur, unit_group: :mass, base_unit: "g", season_months: [], aliases: ["lardon"] },
  { name: "Bacon", category: :charcuterie_traiteur, unit_group: :mass, base_unit: "g", season_months: [], aliases: [] },
  { name: "Saucisse", category: :charcuterie_traiteur, unit_group: :mass, base_unit: "g", season_months: [], aliases: ["saucisses"] },
  { name: "Chorizo", category: :charcuterie_traiteur, unit_group: :mass, base_unit: "g", season_months: [], aliases: [] },
  { name: "Saucisson", category: :charcuterie_traiteur, unit_group: :mass, base_unit: "g", season_months: [], aliases: [] },
  { name: "Pâté", category: :charcuterie_traiteur, unit_group: :mass, base_unit: "g", season_months: [], aliases: [] },
].each { |attrs| Ingredient.create!(attrs) }

# ============================================
# POISSONNERIE (poissonnerie)
# ============================================
puts "  → Poissonnerie..."

[
  { name: "Saumon", category: :poissonnerie, unit_group: :mass, base_unit: "g", season_months: [], aliases: ["pavé de saumon", "filet de saumon"] },
  { name: "Cabillaud", category: :poissonnerie, unit_group: :mass, base_unit: "g", season_months: [], aliases: ["dos de cabillaud"] },
  { name: "Thon", category: :poissonnerie, unit_group: :mass, base_unit: "g", season_months: [], aliases: ["steak de thon"] },
  { name: "Crevettes", category: :poissonnerie, unit_group: :mass, base_unit: "g", season_months: [], aliases: ["crevette"] },
  { name: "Moules", category: :poissonnerie, unit_group: :mass, base_unit: "g", season_months: [], aliases: [] },
  { name: "Sole", category: :poissonnerie, unit_group: :mass, base_unit: "g", season_months: [], aliases: ["filet de sole"] },
  { name: "Truite", category: :poissonnerie, unit_group: :mass, base_unit: "g", season_months: [], aliases: ["filet de truite"] },
  { name: "Sardine", category: :poissonnerie, unit_group: :mass, base_unit: "g", season_months: [], aliases: ["sardines"] },
  { name: "Maquereau", category: :poissonnerie, unit_group: :mass, base_unit: "g", season_months: [], aliases: [] },
].each { |attrs| Ingredient.create!(attrs) }

# ============================================
# FROMAGERIE / COUPE (fromagerie_coupe)
# ============================================
puts "  → Fromagerie / Coupe..."

[
  { name: "Emmental", category: :fromagerie_coupe, unit_group: :mass, base_unit: "g", season_months: [], aliases: ["emmental râpé"] },
  { name: "Gruyère", category: :fromagerie_coupe, unit_group: :mass, base_unit: "g", season_months: [], aliases: ["gruyère râpé"] },
  { name: "Parmesan", category: :fromagerie_coupe, unit_group: :mass, base_unit: "g", season_months: [], aliases: ["parmesan râpé"] },
  { name: "Mozzarella", category: :fromagerie_coupe, unit_group: :mass, base_unit: "g", season_months: [], aliases: [] },
  { name: "Chèvre", category: :fromagerie_coupe, unit_group: :mass, base_unit: "g", season_months: [], aliases: ["fromage de chèvre"] },
  { name: "Roquefort", category: :fromagerie_coupe, unit_group: :mass, base_unit: "g", season_months: [], aliases: [] },
  { name: "Comté", category: :fromagerie_coupe, unit_group: :mass, base_unit: "g", season_months: [], aliases: [] },
  { name: "Brie", category: :fromagerie_coupe, unit_group: :mass, base_unit: "g", season_months: [], aliases: [] },
  { name: "Camembert", category: :fromagerie_coupe, unit_group: :mass, base_unit: "g", season_months: [], aliases: [] },
].each { |attrs| Ingredient.create!(attrs) }

# ============================================
# BOULANGERIE / PÂTISSERIE (boulangerie_patisserie)
# ============================================
puts "  → Boulangerie / Pâtisserie..."

[
  { name: "Pain", category: :boulangerie_patisserie, unit_group: :mass, base_unit: "g", season_months: [], aliases: ["baguette"] },
  { name: "Pain de mie", category: :boulangerie_patisserie, unit_group: :count, base_unit: "piece", season_months: [], aliases: ["tranche de pain de mie"] },
  { name: "Croissant", category: :boulangerie_patisserie, unit_group: :count, base_unit: "piece", season_months: [], aliases: ["croissants"] },
  { name: "Brioche", category: :boulangerie_patisserie, unit_group: :mass, base_unit: "g", season_months: [], aliases: [] },
].each { |attrs| Ingredient.create!(attrs) }

# ============================================
# PRODUITS LAITIERS (produits_laitiers)
# ============================================
puts "  → Produits laitiers..."

[
  { name: "Lait entier", category: :produits_laitiers, unit_group: :volume, base_unit: "ml", season_months: [], aliases: [] },
  { name: "Lait demi-écrémé", category: :produits_laitiers, unit_group: :volume, base_unit: "ml", season_months: [], aliases: [] },
  { name: "Crème fraîche épaisse", category: :produits_laitiers, unit_group: :volume, base_unit: "ml", season_months: [], aliases: ["crème épaisse"] },
  { name: "Crème fraîche liquide", category: :produits_laitiers, unit_group: :volume, base_unit: "ml", season_months: [], aliases: ["crème liquide"] },
  { name: "Beurre", category: :produits_laitiers, unit_group: :mass, base_unit: "g", season_months: [], aliases: [] },
  { name: "Beurre demi-sel", category: :produits_laitiers, unit_group: :mass, base_unit: "g", season_months: [], aliases: [] },
  { name: "Yaourt nature", category: :produits_laitiers, unit_group: :count, base_unit: "piece", season_months: [], aliases: ["yaourts nature"] },
  { name: "Yaourt aux fruits", category: :produits_laitiers, unit_group: :count, base_unit: "piece", season_months: [], aliases: [] },
  { name: "Fromage blanc", category: :produits_laitiers, unit_group: :mass, base_unit: "g", season_months: [], aliases: [] },
  { name: "Œuf", category: :produits_laitiers, unit_group: :count, base_unit: "piece", season_months: [], aliases: ["œufs"] },
].each { |attrs| Ingredient.create!(attrs) }

# ============================================
# PRODUITS FRAIS EN LIBRE-SERVICE (produits_frais_libre_service)
# ============================================
puts "  → Produits frais en libre-service..."

[
  { name: "Pâte feuilletée", category: :produits_frais_libre_service, unit_group: :count, base_unit: "piece", season_months: [], aliases: [] },
  { name: "Pâte brisée", category: :produits_frais_libre_service, unit_group: :count, base_unit: "piece", season_months: [], aliases: [] },
  { name: "Pâte sablée", category: :produits_frais_libre_service, unit_group: :count, base_unit: "piece", season_months: [], aliases: [] },
].each { |attrs| Ingredient.create!(attrs) }

# ============================================
# GLACES ET DESSERTS GLACÉS (glaces_desserts_glaces)
# ============================================
puts "  → Glaces et desserts glacés..."

[
  { name: "Glace vanille", category: :glaces_desserts_glaces, unit_group: :volume, base_unit: "ml", season_months: [], aliases: [] },
  { name: "Sorbet citron", category: :glaces_desserts_glaces, unit_group: :volume, base_unit: "ml", season_months: [], aliases: [] },
].each { |attrs| Ingredient.create!(attrs) }

# ============================================
# LÉGUMES SURGELÉS (legumes_surgeles)
# ============================================
puts "  → Légumes surgelés..."

[
  { name: "Haricots verts surgelés", category: :legumes_surgeles, unit_group: :mass, base_unit: "g", season_months: [], aliases: [] },
  { name: "Petits pois surgelés", category: :legumes_surgeles, unit_group: :mass, base_unit: "g", season_months: [], aliases: [] },
  { name: "Épinards surgelés", category: :legumes_surgeles, unit_group: :mass, base_unit: "g", season_months: [], aliases: [] },
].each { |attrs| Ingredient.create!(attrs) }

# ============================================
# VIANDES ET POISSONS SURGELÉS (viandes_poissons_surgeles)
# ============================================
puts "  → Viandes et poissons surgelés..."

[
  { name: "Poisson pané", category: :viandes_poissons_surgeles, unit_group: :count, base_unit: "piece", season_months: [], aliases: ["poissons panés"] },
  { name: "Crevettes surgelées", category: :viandes_poissons_surgeles, unit_group: :mass, base_unit: "g", season_months: [], aliases: [] },
].each { |attrs| Ingredient.create!(attrs) }

# ============================================
# PRODUITS APÉRITIFS SURGELÉS (produits_aperitifs_surgeles)
# ============================================
puts "  → Produits apéritifs surgelés..."

[
  { name: "Mini-pizza", category: :produits_aperitifs_surgeles, unit_group: :count, base_unit: "piece", season_months: [], aliases: ["mini-pizzas"] },
].each { |attrs| Ingredient.create!(attrs) }

# ============================================
# ÉPICERIE SALÉE (epicerie_salee)
# ============================================
puts "  → Épicerie salée..."

[
  # Féculents et céréales
  { name: "Pâtes", category: :epicerie_salee, unit_group: :mass, base_unit: "g", season_months: [], aliases: [] },
  { name: "Spaghetti", category: :epicerie_salee, unit_group: :mass, base_unit: "g", season_months: [], aliases: ["spaghettis"] },
  { name: "Penne", category: :epicerie_salee, unit_group: :mass, base_unit: "g", season_months: [], aliases: [] },
  { name: "Tagliatelles", category: :epicerie_salee, unit_group: :mass, base_unit: "g", season_months: [], aliases: [] },
  { name: "Riz", category: :epicerie_salee, unit_group: :mass, base_unit: "g", season_months: [], aliases: [] },
  { name: "Riz basmati", category: :epicerie_salee, unit_group: :mass, base_unit: "g", season_months: [], aliases: [] },
  { name: "Quinoa", category: :epicerie_salee, unit_group: :mass, base_unit: "g", season_months: [], aliases: [] },
  { name: "Couscous", category: :epicerie_salee, unit_group: :mass, base_unit: "g", season_months: [], aliases: ["semoule"] },
  { name: "Lentilles", category: :epicerie_salee, unit_group: :mass, base_unit: "g", season_months: [], aliases: [] },
  { name: "Pois chiches", category: :epicerie_salee, unit_group: :mass, base_unit: "g", season_months: [], aliases: [] },
  
  # Farines et bases
  { name: "Farine", category: :epicerie_salee, unit_group: :mass, base_unit: "g", season_months: [], aliases: ["farine de blé"] },
  { name: "Fécule de maïs", category: :epicerie_salee, unit_group: :mass, base_unit: "g", season_months: [], aliases: ["maïzena"] },
  
  # Huiles et vinaigres
  { name: "Huile d'olive", category: :epicerie_salee, unit_group: :volume, base_unit: "ml", season_months: [], aliases: [] },
  { name: "Huile de tournesol", category: :epicerie_salee, unit_group: :volume, base_unit: "ml", season_months: [], aliases: [] },
  { name: "Vinaigre", category: :epicerie_salee, unit_group: :volume, base_unit: "ml", season_months: [], aliases: ["vinaigre de vin"] },
  { name: "Vinaigre balsamique", category: :epicerie_salee, unit_group: :volume, base_unit: "ml", season_months: [], aliases: [] },
  
  # Conserves
  { name: "Tomate concassée", category: :epicerie_salee, unit_group: :mass, base_unit: "g", season_months: [], aliases: ["tomates concassées en conserve"] },
  { name: "Concentré de tomate", category: :epicerie_salee, unit_group: :mass, base_unit: "g", season_months: [], aliases: [] },
  { name: "Thon en boîte", category: :epicerie_salee, unit_group: :mass, base_unit: "g", season_months: [], aliases: [] },
  { name: "Maïs en boîte", category: :epicerie_salee, unit_group: :mass, base_unit: "g", season_months: [], aliases: [] },
  
  # Condiments et sauces
  { name: "Moutarde", category: :epicerie_salee, unit_group: :spoon, base_unit: "cac", season_months: [], aliases: [] },
  { name: "Mayonnaise", category: :epicerie_salee, unit_group: :spoon, base_unit: "cac", season_months: [], aliases: [] },
  { name: "Ketchup", category: :epicerie_salee, unit_group: :spoon, base_unit: "cac", season_months: [], aliases: [] },
  { name: "Sauce soja", category: :epicerie_salee, unit_group: :spoon, base_unit: "cac", season_months: [], aliases: [] },
  
  # Épices et aromates
  { name: "Sel", category: :epicerie_salee, unit_group: :spoon, base_unit: "cac", season_months: [], aliases: ["sel fin"] },
  { name: "Sel de Guérande", category: :epicerie_salee, unit_group: :spoon, base_unit: "cac", season_months: [], aliases: ["gros sel"] },
  { name: "Poivre", category: :epicerie_salee, unit_group: :spoon, base_unit: "cac", season_months: [], aliases: ["poivre moulu"] },
  { name: "Poivre en grains", category: :epicerie_salee, unit_group: :spoon, base_unit: "cac", season_months: [], aliases: [] },
  { name: "Paprika", category: :epicerie_salee, unit_group: :spoon, base_unit: "cac", season_months: [], aliases: [] },
  { name: "Curry", category: :epicerie_salee, unit_group: :spoon, base_unit: "cac", season_months: [], aliases: ["poudre de curry"] },
  { name: "Cumin", category: :epicerie_salee, unit_group: :spoon, base_unit: "cac", season_months: [], aliases: [] },
  { name: "Curcuma", category: :epicerie_salee, unit_group: :spoon, base_unit: "cac", season_months: [], aliases: [] },
  { name: "Piment", category: :epicerie_salee, unit_group: :spoon, base_unit: "cac", season_months: [], aliases: ["poudre de piment"] },
  { name: "Piment d'Espelette", category: :epicerie_salee, unit_group: :spoon, base_unit: "cac", season_months: [], aliases: [] },
  { name: "Gingembre moulu", category: :epicerie_salee, unit_group: :spoon, base_unit: "cac", season_months: [], aliases: ["gingembre en poudre"] },
  { name: "Muscade", category: :epicerie_salee, unit_group: :spoon, base_unit: "cac", season_months: [], aliases: ["noix de muscade"] },
  { name: "Herbes de Provence", category: :epicerie_salee, unit_group: :spoon, base_unit: "cac", season_months: [], aliases: [] },
  { name: "Thym séché", category: :epicerie_salee, unit_group: :spoon, base_unit: "cac", season_months: [], aliases: [] },
  { name: "Origan séché", category: :epicerie_salee, unit_group: :spoon, base_unit: "cac", season_months: [], aliases: [] },
  { name: "Basilic séché", category: :epicerie_salee, unit_group: :spoon, base_unit: "cac", season_months: [], aliases: [] },
  { name: "Persil séché", category: :epicerie_salee, unit_group: :spoon, base_unit: "cac", season_months: [], aliases: [] },
  { name: "Coriandre moulue", category: :epicerie_salee, unit_group: :spoon, base_unit: "cac", season_months: [], aliases: [] },
  { name: "Laurier", category: :epicerie_salee, unit_group: :count, base_unit: "piece", season_months: [], aliases: ["feuille de laurier"] },
  { name: "Cannelle", category: :epicerie_salee, unit_group: :spoon, base_unit: "cac", season_months: [], aliases: ["cannelle en poudre"] },
  
  # Herbes fraîches
  { name: "Persil frais", category: :epicerie_salee, unit_group: :mass, base_unit: "g", season_months: [], aliases: ["bouquet de persil"] },
  { name: "Ciboulette", category: :epicerie_salee, unit_group: :mass, base_unit: "g", season_months: [], aliases: [] },
  { name: "Basilic frais", category: :epicerie_salee, unit_group: :mass, base_unit: "g", season_months: [], aliases: [] },
  { name: "Coriandre fraîche", category: :epicerie_salee, unit_group: :mass, base_unit: "g", season_months: [], aliases: [] },
  { name: "Menthe fraîche", category: :epicerie_salee, unit_group: :mass, base_unit: "g", season_months: [], aliases: [] },
  { name: "Thym frais", category: :epicerie_salee, unit_group: :mass, base_unit: "g", season_months: [], aliases: [] },
  { name: "Romarin frais", category: :epicerie_salee, unit_group: :mass, base_unit: "g", season_months: [], aliases: [] },
  
  # Bouillons
  { name: "Bouillon de volaille", category: :epicerie_salee, unit_group: :volume, base_unit: "ml", season_months: [], aliases: ["bouillon de poulet"] },
  { name: "Bouillon de légumes", category: :epicerie_salee, unit_group: :volume, base_unit: "ml", season_months: [], aliases: [] },
  { name: "Bouillon de bœuf", category: :epicerie_salee, unit_group: :volume, base_unit: "ml", season_months: [], aliases: [] },
].each { |attrs| Ingredient.create!(attrs) }

# ============================================
# ÉPICERIE SUCRÉE (epicerie_sucree)
# ============================================
puts "  → Épicerie sucrée..."

[
  { name: "Sucre", category: :epicerie_sucree, unit_group: :mass, base_unit: "g", season_months: [], aliases: ["sucre blanc", "sucre en poudre"] },
  { name: "Sucre roux", category: :epicerie_sucree, unit_group: :mass, base_unit: "g", season_months: [], aliases: ["cassonade"] },
  { name: "Sucre glace", category: :epicerie_sucree, unit_group: :mass, base_unit: "g", season_months: [], aliases: [] },
  { name: "Sucre vanillé", category: :epicerie_sucree, unit_group: :count, base_unit: "piece", season_months: [], aliases: ["sachet de sucre vanillé"] },
  { name: "Vanille", category: :epicerie_sucree, unit_group: :count, base_unit: "piece", season_months: [], aliases: ["gousse de vanille"] },
  { name: "Extrait de vanille", category: :epicerie_sucree, unit_group: :spoon, base_unit: "cac", season_months: [], aliases: [] },
  { name: "Miel", category: :epicerie_sucree, unit_group: :spoon, base_unit: "cac", season_months: [], aliases: [] },
  { name: "Confiture", category: :epicerie_sucree, unit_group: :spoon, base_unit: "cac", season_months: [], aliases: [] },
  { name: "Nutella", category: :epicerie_sucree, unit_group: :spoon, base_unit: "cac", season_months: [], aliases: ["pâte à tartiner"] },
  { name: "Chocolat noir", category: :epicerie_sucree, unit_group: :mass, base_unit: "g", season_months: [], aliases: [] },
  { name: "Chocolat au lait", category: :epicerie_sucree, unit_group: :mass, base_unit: "g", season_months: [], aliases: [] },
  { name: "Pépites de chocolat", category: :epicerie_sucree, unit_group: :mass, base_unit: "g", season_months: [], aliases: [] },
  { name: "Cacao en poudre", category: :epicerie_sucree, unit_group: :spoon, base_unit: "cac", season_months: [], aliases: ["cacao"] },
  { name: "Levure chimique", category: :epicerie_sucree, unit_group: :count, base_unit: "piece", season_months: [], aliases: ["sachet de levure"] },
  { name: "Bicarbonate", category: :epicerie_sucree, unit_group: :spoon, base_unit: "cac", season_months: [], aliases: ["bicarbonate de soude"] },
  { name: "Gélatine", category: :epicerie_sucree, unit_group: :count, base_unit: "piece", season_months: [], aliases: ["feuille de gélatine"] },
  { name: "Amande en poudre", category: :epicerie_sucree, unit_group: :mass, base_unit: "g", season_months: [], aliases: ["poudre d'amande"] },
  { name: "Noix", category: :epicerie_sucree, unit_group: :mass, base_unit: "g", season_months: [], aliases: [] },
  { name: "Noisettes", category: :epicerie_sucree, unit_group: :mass, base_unit: "g", season_months: [], aliases: [] },
  { name: "Raisins secs", category: :epicerie_sucree, unit_group: :mass, base_unit: "g", season_months: [], aliases: [] },
].each { |attrs| Ingredient.create!(attrs) }

# ============================================
# BOISSONS (boissons)
# ============================================
puts "  → Boissons..."

[
  { name: "Eau", category: :boissons, unit_group: :volume, base_unit: "ml", season_months: [], aliases: ["eau minérale"] },
  { name: "Eau gazeuse", category: :boissons, unit_group: :volume, base_unit: "ml", season_months: [], aliases: [] },
  { name: "Jus d'orange", category: :boissons, unit_group: :volume, base_unit: "ml", season_months: [], aliases: [] },
  { name: "Jus de citron", category: :boissons, unit_group: :volume, base_unit: "ml", season_months: [], aliases: [] },
  { name: "Coca-Cola", category: :boissons, unit_group: :volume, base_unit: "ml", season_months: [], aliases: ["coca"] },
  { name: "Vin blanc", category: :boissons, unit_group: :volume, base_unit: "ml", season_months: [], aliases: [] },
  { name: "Vin rouge", category: :boissons, unit_group: :volume, base_unit: "ml", season_months: [], aliases: [] },
  { name: "Bière", category: :boissons, unit_group: :volume, base_unit: "ml", season_months: [], aliases: [] },
].each { |attrs| Ingredient.create!(attrs) }

# ============================================
# PETIT-DÉJEUNER (petit_dejeuner)
# ============================================
puts "  → Petit-déjeuner..."

[
  { name: "Café", category: :petit_dejeuner, unit_group: :spoon, base_unit: "cac", season_months: [], aliases: ["café moulu"] },
  { name: "Thé", category: :petit_dejeuner, unit_group: :count, base_unit: "piece", season_months: [], aliases: ["sachet de thé"] },
  { name: "Céréales", category: :petit_dejeuner, unit_group: :mass, base_unit: "g", season_months: [], aliases: [] },
  { name: "Muesli", category: :petit_dejeuner, unit_group: :mass, base_unit: "g", season_months: [], aliases: [] },
  { name: "Flocons d'avoine", category: :petit_dejeuner, unit_group: :mass, base_unit: "g", season_months: [], aliases: [] },
].each { |attrs| Ingredient.create!(attrs) }

# ============================================
# PRODUITS DU MONDE (produits_monde)
# ============================================
puts "  → Produits du monde..."

[
  { name: "Sauce curry", category: :produits_monde, unit_group: :spoon, base_unit: "cac", season_months: [], aliases: [] },
  { name: "Lait de coco", category: :produits_monde, unit_group: :volume, base_unit: "ml", season_months: [], aliases: [] },
  { name: "Gingembre frais", category: :produits_monde, unit_group: :mass, base_unit: "g", season_months: [], aliases: [] },
].each { |attrs| Ingredient.create!(attrs) }

# ============================================
# HYGIÈNE ET BEAUTÉ (hygiene_beaute)
# ============================================
puts "  → Hygiène et beauté..."

# (Pas d'ingrédients alimentaires ici - catégorie pour complétude)

# ============================================
# ENTRETIEN DE LA MAISON (entretien_maison)
# ============================================
puts "  → Entretien de la maison..."

# (Pas d'ingrédients alimentaires ici - catégorie pour complétude)

# ============================================
# PAPETERIE ET FOURNITURES (papeterie_fournitures)
# ============================================
puts "  → Papeterie et fournitures..."

[
  { name: "Papier sulfurisé", category: :papeterie_fournitures, unit_group: :count, base_unit: "piece", season_months: [], aliases: ["papier cuisson"] },
  { name: "Papier aluminium", category: :papeterie_fournitures, unit_group: :count, base_unit: "piece", season_months: [], aliases: ["aluminium"] },
  { name: "Film alimentaire", category: :papeterie_fournitures, unit_group: :count, base_unit: "piece", season_months: [], aliases: [] },
].each { |attrs| Ingredient.create!(attrs) }

total = Ingredient.count
puts "\n✅ #{total} ingrédients créés avec succès!"
puts "\nRépartition par rayon:"
Ingredient.group(:category).count.each do |category, count|
  puts "  - #{Ingredient.human_attribute_name("category.#{category}")}: #{count}"
end
