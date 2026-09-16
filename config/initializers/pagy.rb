# Pagy initializer
# Documentation: https://ddnexus.github.io/pagy/docs/api/pagy

# Nombre d’items par page par défaut (clé :limit depuis Pagy 9)
Pagy::DEFAULT[:limit] = 20

# Libellés en français (aria-label « Précédent » / « Suivant », « Pages »…) :
# dictionnaire fourni par la gem, seule locale chargée donc locale par défaut.
Pagy::I18n.load(locale: "fr")

# Optionnel: Utiliser le compteur pour de meilleures performances
# Pagy::DEFAULT[:count_args] = [:all]

# Optionnel: Activer le trim des pages (enlever les zéros inutiles)
Pagy::DEFAULT[:page_param] = :page
