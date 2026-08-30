# Rendu Turbo Stream d'un message flash (partagé par tous les controllers)
# Évite la duplication de render_flash_stream dans chaque controller.
module TurboFlashable
  extend ActiveSupport::Concern

  private

  # @param messages [Hash] type de flash => message, comme le flash Rails
  #   (:alert, :notice…) — le partial en tire la classe CSS du bandeau.
  def render_flash_stream(**messages)
    render turbo_stream: turbo_stream.replace(
      "flash",
      partial: "shared/flash",
      locals: { flash: messages }
    )
  end

  # Répond en Turbo Stream + HTML après une action réussie.
  # redirect_path : chemin de redirection pour le fallback HTML
  def respond_success(redirect_path:, notice: nil)
    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to redirect_path, notice: notice }
    end
  end

  # Répond en Turbo Stream + HTML par une simple information, sans rien avoir
  # écrit : l'action n'avait pas lieu d'être (l'article demandé était déjà dans
  # la liste). Ni une réussite — il n'y a rien de neuf à afficher — ni une
  # erreur de saisie, d'où le ton et la couleur du bandeau.
  def respond_notice(message, redirect_path:)
    respond_to do |format|
      format.turbo_stream { render_flash_stream(notice: message) }
      format.html { redirect_to redirect_path, notice: message }
    end
  end

  # Répond en Turbo Stream + HTML après une erreur de validation.
  # Cacheé le message d'erreur pour éviter les appels dupliqués.
  def respond_error(record, redirect_path:)
    error_message = record.errors.full_messages.to_sentence
    respond_to do |format|
      format.turbo_stream { render_flash_stream(alert: error_message) }
      format.html { redirect_to redirect_path, alert: error_message }
    end
  end
end
