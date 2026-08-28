# frozen_string_literal: true

module Ingredients
  # Va chercher auprès de l'IA la densité qui manque à un ingrédient, et l'écrit
  # en disant d'où elle vient : `density_source: ai`, c'est-à-dire « à vérifier »
  # partout où elle s'affiche. Une estimation n'entre jamais en base sans cette
  # étiquette — sans elle, une valeur fausse fausserait en silence les quantités
  # de la liste de courses.
  #
  # En tâche de fond parce que rien n'attend cette valeur : l'import se termine
  # sans elle, et la conversion qu'elle débloque n'est proposée qu'ensuite.
  class EstimateDensityJob < ApplicationJob
    queue_as :default

    def perform(ingredient)
      # Rejeu défensif, et course entre deux imports : une densité déjà connue —
      # curatée comme estimée — ne se redemande pas, ce serait un appel facturé
      # pour le même résultat.
      return if ingredient.density_g_per_ml.present?

      density = estimate(ingredient.name)
      return if density.blank?

      # update et non update! : la validation borne ce que l'IA peut écrire
      # (Ingredient::MAX_DENSITY), et un ingrédient sans densité reste un cas
      # prévu partout en aval. Un refus se consigne, il n'interrompt rien.
      return if ingredient.update(density_g_per_ml: density, density_source: :ai)

      log("densité refusée pour #{ingredient.name} : #{ingredient.errors.full_messages.to_sentence}")
    end

    private

    def estimate(name)
      answer = Recipes::ClaudeClient.call(DensityPrompt.request(name))
      answer["density_g_per_ml"]
    rescue Recipes::ExtractionError => e
      # L'estimation est un confort, pas une étape de l'import : sa panne ne doit
      # rien interrompre. La conversion restera signalée comme impossible, ce
      # qu'elle était déjà avant cette tentative.
      log("estimation impossible pour #{name} : #{e.message}")
      nil
    end

    def log(message)
      Rails.logger.info("[EstimateDensityJob] #{message}")
    end
  end
end
