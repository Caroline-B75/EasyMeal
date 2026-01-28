# Pagy initializer
# Documentation: https://ddnexus.github.io/pagy/docs/api/pagy

# Nombre d'items par page par défaut
Pagy::DEFAULT[:items] = 20

# Optionnel: Support I18n pour les traductions
# Pagy::DEFAULT[:i18n_key] = 'pagy.item_name'

# Optionnel: Utiliser le compteur pour de meilleures performances
# Pagy::DEFAULT[:count_args] = [:all]

# Optionnel: Activer le trim des pages (enlever les zéros inutiles)
Pagy::DEFAULT[:page_param] = :page
