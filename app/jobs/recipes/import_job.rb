# frozen_string_literal: true

require "base64"

module Recipes
  # Le commis de l'import : il fait le travail long — aller chercher la page ou
  # lire la photo, interroger l'IA, écrire le brouillon — hors du cycle de la
  # requête HTTP.
  #
  # C'est toute la raison de ce job : l'extraction demande jusqu'à 60 s
  # (ClaudeClient::TIMEOUT) alors que les routeurs d'hébergeurs abandonnent une
  # requête vers 30 s. Le formulaire répond donc tout de suite, et la page
  # d'attente suit l'avancement dans le RecipeImport.
  class ImportJob < ApplicationJob
    queue_as :default

    def perform(import)
      # Rejeu défensif : un import déjà abouti ne se refait pas (ce serait un
      # second appel à l'IA, facturé, pour le même résultat).
      return if import.finished?

      import.processing!
      recipe = DraftBuilder.call(import, extract(import))

      if recipe.save
        # Le brouillon a repris le fichier de l'import : on détache celui-ci —
        # détacher ne supprime pas le fichier, il en cède la propriété. Sans ça,
        # deux enregistrements se partageraient le même blob et la suppression de
        # l'un emporterait l'image de l'autre.
        import.source_photo.detach if import.source_photo.attached?
        # « 1 c. à s. de farine » ne se pèse pas sans la densité de la farine :
        # on lance l'estimation de celles qui manquent avant de rendre la main, le
        # temps que l'utilisatrice arrive sur la page de revue.
        Ingredients::MissingDensityService.call(recipe.ai_raw_data["ingredients"])
        import.succeed_with!(recipe)
      else
        import.fail_with!("Impossible de créer le brouillon : #{recipe.errors.full_messages.to_sentence}")
      end
    rescue ExtractionError => e
      import.fail_with!("Extraction échouée : #{e.message}")
    rescue StandardError
      # Un bug ne doit pas laisser la page d'attente tourner sans fin : l'import
      # est clos avec un message honnête, et l'erreur remonte pour être vue
      # (GoodJob la consigne dans sa propre table).
      import.fail_with!("Une erreur inattendue a interrompu l'import.")
      raise
    end

    private

    def extract(import)
      return ExtractorService.from_url(import.source_url) if import.from_url?

      photo = import.source_photo
      raise ExtractionError, "La photo de l'import est introuvable" unless photo.attached?

      ExtractorService.from_photo(Base64.strict_encode64(photo.download),
                                 media_type: photo.blob.content_type)
    end
  end
end
