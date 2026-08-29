# frozen_string_literal: true

module Images
  # Lit la définition d'une image dans son en-tête, sans bibliothèque de
  # traitement d'image.
  #
  # Le serveur n'a volontairement ni libvips ni ImageMagick — les vignettes sont
  # produites par les URL de transformation Cloudinary (cf. RecipesHelper) —, mais
  # il doit tout de même refuser une photo au-delà des 25 mégapixels que
  # Cloudinary accepte. Or la définition tient dans les premiers octets du
  # fichier : quelques dizaines d'octets lus suffisent, là où décoder l'image
  # entière coûterait sa taille en mémoire.
  #
  # JPEG et PNG seulement : ce sont les deux formats dans lesquels arrivent une
  # photo de téléphone et une capture d'écran, les seuls à dépasser 25 MP en
  # pratique. Tout autre format rend nil — l'appelant s'en remet alors au seul
  # plafond de poids.
  module Dimensions
    # De quoi couvrir l'en-tête PNG (33 octets) comme la traversée des segments
    # JPEG jusqu'au SOF, que les métadonnées d'un téléphone (EXIF, vignette,
    # profil couleur) repoussent parfois loin dans le fichier.
    HEADER_BYTES = 128 * 1024

    PNG_SIGNATURE = "\x89PNG\r\n\x1A\n".b.freeze
    JPEG_SIGNATURE = "\xFF\xD8".b.freeze

    # Les marqueurs SOF portent la définition. C4 (tables de Huffman), C8
    # (extension JPEG) et CC (tables arithmétiques) partagent la plage sans en
    # être : ils se sautent comme n'importe quel autre segment.
    SOF_MARKERS = ((0xC0..0xCF).to_a - [ 0xC4, 0xC8, 0xCC ]).freeze

    # Marqueurs isolés — remplissage, redémarrage, début d'image — qui n'ouvrent
    # aucun segment et ne sont donc suivis d'aucune longueur à sauter.
    STANDALONE_MARKERS = ([ 0x01, 0xFF ] + (0xD0..0xD9).to_a).freeze

    class << self
      # [largeur, hauteur] en pixels, ou nil si l'en-tête n'est pas exploitable.
      def read(io)
        return nil unless io.respond_to?(:read)

        io.rewind if io.respond_to?(:rewind)
        header = io.read(HEADER_BYTES).to_s.b

        png(header) || jpeg(header)
      rescue IOError, SystemCallError
        nil
      ensure
        io.rewind if io.respond_to?(:rewind)
      end

      private

      # Le chunk IHDR ouvre obligatoirement un PNG : largeur et hauteur y sont
      # deux entiers 32 bits big-endian, à position fixe.
      def png(header)
        return nil unless header.start_with?(PNG_SIGNATURE)

        header[16, 8]&.then { |bytes| bytes.bytesize == 8 ? bytes.unpack("N2") : nil }
      end

      # Parcours des segments jusqu'au SOF. Chaque segment annonce sa longueur,
      # ce qui permet de sauter les métadonnées sans les interpréter.
      def jpeg(header)
        return nil unless header.start_with?(JPEG_SIGNATURE)

        offset = 2
        while (offset = next_marker(header, offset))
          return sof_dimensions(header, offset) if SOF_MARKERS.include?(header.getbyte(offset + 1))

          offset = after_segment(header, offset)
          return nil unless offset
        end

        nil
      end

      # Position du prochain marqueur — un FF suivi de son identifiant — à partir
      # de +offset+, ou nil s'il n'en reste plus dans l'en-tête lu. Tout autre
      # octet est un décalage à rattraper plutôt qu'un segment.
      def next_marker(header, offset)
        offset += 1 while offset + 4 <= header.bytesize && header.getbyte(offset) != 0xFF

        offset + 4 <= header.bytesize ? offset : nil
      end

      # Position qui suit le segment ouvert en +offset+, ou nil si sa longueur
      # est inexploitable. Les marqueurs isolés n'ouvrent aucun segment.
      def after_segment(header, offset)
        return offset + 2 if STANDALONE_MARKERS.include?(header.getbyte(offset + 1))

        length = header[offset + 2, 2]&.unpack1("n")
        return nil if length.nil? || length < 2

        offset + 2 + length
      end

      # Le SOF annonce 1 octet de précision, puis la hauteur et la largeur sur
      # 2 octets chacune — dans cet ordre, que l'on remet à l'endroit.
      def sof_dimensions(header, offset)
        values = header[offset + 5, 4]
        return nil unless values&.bytesize == 4

        values.unpack("n2").reverse
      end
    end
  end
end
