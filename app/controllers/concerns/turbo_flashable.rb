# Rendu Turbo Stream d'un message flash (partagé par tous les controllers)
# Évite la duplication de render_flash_stream dans chaque controller.
module TurboFlashable
  extend ActiveSupport::Concern

  private

  # @param messages [Hash] type de flash => message, comme le flash Rails
  #   (:alert, :notice…) — le partial en tire la classe CSS du bandeau.
  #
  # `update` et non `replace` : le conteneur #flash (positionné, annoncé aux
  # lecteurs d'écran) doit survivre au message, sans quoi le suivant n'aurait
  # plus où s'afficher.
  def render_flash_stream(**messages)
    render turbo_stream: turbo_stream.update(
      "flash",
      partial: "shared/flash",
      locals: { flash: messages }
    )
  end

  # Répond en Turbo Stream + HTML après une action réussie.
  # redirect_path : chemin de redirection pour le fallback HTML
  # notice        : message éventuel — le bandeau après la redirection, ou
  #                 flash.now, que le template Turbo Stream peut rendre (shared/flash)
  def respond_success(redirect_path:, notice: nil)
    respond_to do |format|
      format.turbo_stream { flash.now[:notice] = notice if notice }
      format.html { redirect_to redirect_path, notice: notice }
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
