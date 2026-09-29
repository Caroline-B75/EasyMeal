# Pagy initializer
# Documentation: https://ddnexus.github.io/pagy/docs/api/pagy

require "pagy/extras/overflow"

# Nombre d’items par page par défaut (clé :limit depuis Pagy 9)
Pagy::DEFAULT[:limit] = 20

# Une page au-delà de la dernière — vieux lien, filtre ajouté depuis la page 2,
# recette supprimée entre-temps — affiche la dernière page au lieu de lever
# Pagy::OverflowError (erreur 500).
Pagy::DEFAULT[:overflow] = :last_page

# Libellés en français (aria-label « Précédent » / « Suivant », « Pages »…) :
# dictionnaire fourni par la gem, seule locale chargée donc locale par défaut.
Pagy::I18n.load(locale: "fr")

# Optionnel: Utiliser le compteur pour de meilleures performances
# Pagy::DEFAULT[:count_args] = [:all]

# Optionnel: Activer le trim des pages (enlever les zéros inutiles)
Pagy::DEFAULT[:page_param] = :page
