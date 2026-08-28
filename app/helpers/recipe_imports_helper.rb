# frozen_string_literal: true

# Habille l'attente d'un import IA.
module RecipeImportsHelper
  # Étapes traversées pendant l'extraction, dans leur ordre réel. Le serveur ne
  # sait pas dire où l'IA en est : plutôt qu'une fausse progression chiffrée, on
  # annonce ce qui se passe, en se réglant sur le temps écoulé depuis le dépôt.
  #
  # C'est bien le serveur qui choisit, et non un minuteur dans le navigateur :
  # la page d'attente se recharge à chaque vérification, un compteur JS
  # repartirait donc de zéro à chaque fois et resterait bloqué sur la première
  # étape.
  FIRST_STEPS = { "url" => "Lecture de la page…", "photo" => "Lecture de la photo…" }.freeze
  AI_STEP     = "Extraction par l'IA…"
  LAST_STEP   = "Encore quelques secondes…"

  # Bornes de bascule, en secondes depuis la création de l'import.
  FIRST_STEP_UNTIL = 6
  AI_STEP_UNTIL    = 15

  def import_step_label(import)
    elapsed = Time.current - import.created_at

    return FIRST_STEPS.fetch(import.source_type, AI_STEP) if elapsed < FIRST_STEP_UNTIL
    return AI_STEP if elapsed < AI_STEP_UNTIL

    LAST_STEP
  end
end
