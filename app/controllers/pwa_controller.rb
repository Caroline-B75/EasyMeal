class PwaController < ApplicationController
  # Page de secours servie par le service worker quand le réseau est indisponible.
  # Rendue sans le layout applicatif : elle doit rester autonome (pas de nav,
  # pas de dépendance à l'utilisateur courant) car elle est pré-cachée puis
  # affichée hors-ligne.
  layout false

  def offline
  end
end
