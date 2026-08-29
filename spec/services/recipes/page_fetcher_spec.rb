# frozen_string_literal: true

require "rails_helper"

# Spec de Recipes::PageFetcher, extrait d'ExtractorService : ces exemples
# étaient auparavant écrits contre ExtractorService#fetch_html, atteint par
# `send` ou indirectement via .from_url. La classe étant maintenant autonome,
# ils l'appellent directement.
#
# Aucun appel réseau réel n'est fait : Net::HTTP.new est intercepté pour router
# chaque connexion vers une réponse simulée (voir #stub_pages). Le fetcher lit
# ses réponses par morceaux (read_body), ce que ce niveau de simulation permet
# de reproduire — d'où ce choix plutôt que WebMock.
RSpec.describe Recipes::PageFetcher do
  # Taille des morceaux livrés par la simulation de read_body. Net::HTTP livre
  # le corps par paquets ; on l'imite pour exercer réellement le contrôle de
  # taille au fil de la lecture.
  let(:chunk_bytes) { 64 }

  # Requêtes GET reçues, pour inspecter le chemin et les en-têtes envoyés.
  let(:page_requests) { [] }

  # Réseau scellé par défaut : toute connexion non explicitement simulée par
  # l'exemple lève une erreur bruyante.
  before { stub_pages({}) }

  # Intercepte Net::HTTP.new et route chaque connexion selon l'hôte appelé.
  #
  # @param pages [Hash] { "exemple.fr" => réponse Net::HTTP }, ou un tableau de
  #   réponses successives pour un même hôte — ce qu'il faut pour simuler une
  #   redirection interne au site. La dernière réponse est resservie ensuite,
  #   ce qui permet de boucler indéfiniment sur une seule.
  def stub_pages(pages)
    queues = pages.transform_values { |responses| Array(responses).dup }

    allow(Net::HTTP).to receive(:new) do |host, _port|
      connection = instance_double(
        Net::HTTP, :use_ssl= => nil, :open_timeout= => nil, :read_timeout= => nil
      )

      # request_get passe au bloc une réponse dont les en-têtes sont lus mais
      # pas le corps : c'est ce contrat que le fetcher exploite pour refuser une
      # page (type, taille) avant de la télécharger.
      allow(connection).to receive(:request_get) do |path, headers, &block|
        page_requests << { host: host, path: path, headers: headers }
        queue = queues.fetch(host) { raise "Requête HTTP non simulée dans cet exemple : GET #{host}" }

        block.call(queue.size > 1 ? queue.shift : queue.first)
      end

      connection
    end
  end

  # Fabrique une vraie réponse Net::HTTP : c'est sa *classe* qui porte la
  # famille (succès / redirection / erreur) que le service teste par `case`, et
  # ses en-têtes réels que lisent content_type et content_length.
  def http_response(klass, code, body: "", headers: {})
    response = klass.new("1.1", code, code)
    headers.each { |name, value| response[name] = value }
    allow(response).to receive(:read_body) do |&block|
      body.scan(/.{1,#{chunk_bytes}}/m).each { |chunk| block.call(chunk) }
    end
    response
  end

  # Une redirection : seule sa famille (3xx) intéresse le fetcher, pas le code
  # exact — 301 et 302 suivent le même chemin. Sans argument, elle n'annonce
  # aucune destination.
  def redirect_response(location = nil)
    http_response(Net::HTTPFound, "302", headers: location ? { "Location" => location } : {})
  end

  def page_response(html, headers: {})
    http_response(
      Net::HTTPOK, "200",
      body:    html,
      headers: { "Content-Type" => "text/html; charset=utf-8" }.merge(headers)
    )
  end

  # ── Cas nominal ─────────────────────────────────────────────────────────

  describe "récupération de la page" do
    it "retourne le corps de la page demandée" do
      stub_pages("exemple.fr" => page_response("<html><body>Tarte</body></html>"))

      expect(described_class.call("https://exemple.fr/tarte")).to eq("<html><body>Tarte</body></html>")
    end

    it "demande le chemin complet, query comprise, et s'annonce par un User-Agent" do
      stub_pages("exemple.fr" => page_response("<html></html>"))

      described_class.call("https://exemple.fr/recettes?id=12")

      expect(page_requests.last).to include(
        host:    "exemple.fr",
        path:    "/recettes?id=12",
        headers: { "User-Agent" => described_class::USER_AGENT }
      )
    end

    # Net::HTTP rend un corps étiqueté ASCII-8BIT : sans ré-étiquetage, Nokogiri
    # travaillerait sur des octets bruts ; sans scrub, un octet illégal ferait
    # ensuite échouer toute manipulation du texte.
    it "ré-étiquette le corps en UTF-8 et remplace les octets illégaux" do
      body = (+"Crème \xE8 brûlée").force_encoding("ASCII-8BIT")
      stub_pages("exemple.fr" => page_response(body))

      html = described_class.call("https://exemple.fr/tarte")

      expect(html.encoding).to eq(Encoding::UTF_8)
      # \xE8 est remplacé par U+FFFD, le caractère de substitution d'Unicode.
      expect(html).to eq("Crème � brûlée")
    end
  end

  # ── Validation de l'URL ─────────────────────────────────────────────────

  describe "validation de l'URL" do
    it "refuse une URL qui n'est pas en http/https" do
      expect { described_class.call("ftp://exemple.fr/tarte") }
        .to raise_error(Recipes::ExtractionError, "URL invalide (doit commencer par http/https)")

      expect { described_class.call(nil) }
        .to raise_error(Recipes::ExtractionError, "URL invalide (doit commencer par http/https)")
    end

    it "refuse une URL syntaxiquement invalide" do
      expect { described_class.call("https://exemple .fr/tarte") }
        .to raise_error(Recipes::ExtractionError, "URL invalide")
    end
  end

  # ── Redirections ────────────────────────────────────────────────────────

  describe "redirections" do
    it "suit une redirection jusqu'à la page finale" do
      stub_pages(
        "ancien.fr"  => redirect_response("https://nouveau.fr/tarte"),
        "nouveau.fr" => page_response("<html><body>Tarte</body></html>")
      )

      expect(described_class.call("https://ancien.fr/tarte")).to eq("<html><body>Tarte</body></html>")
      expect(page_requests.map { |request| request[:host] }).to eq([ "ancien.fr", "nouveau.fr" ])
    end

    # Beaucoup de sites renvoient un Location relatif ("/recettes/tarte.html") :
    # sans résolution contre l'URL courante, il n'y a plus ni hôte ni schéma.
    it "résout une redirection dont la destination est relative" do
      stub_pages(
        "exemple.fr" => [
          redirect_response("/recettes/tarte.html"),
          page_response("<html><body>Tarte</body></html>")
        ]
      )

      expect(described_class.call("https://exemple.fr/vieux/lien")).to eq("<html><body>Tarte</body></html>")
      expect(page_requests.map { |request| request[:path] }).to eq([ "/vieux/lien", "/recettes/tarte.html" ])
    end

    it "refuse une redirection sans destination" do
      stub_pages("exemple.fr" => redirect_response)

      expect { described_class.call("https://exemple.fr/tarte") }
        .to raise_error(Recipes::ExtractionError, "Redirection sans destination")
    end

    # Chaque saut repasse par la validation : une redirection ne peut pas faire
    # sortir du web (javascript:, file:, ftp:…).
    it "applique la validation du schéma à la destination d'une redirection" do
      stub_pages("exemple.fr" => redirect_response("ftp://exemple.fr/tarte"))

      expect { described_class.call("https://exemple.fr/tarte") }
        .to raise_error(Recipes::ExtractionError, "URL invalide (doit commencer par http/https)")
    end

    it "abandonne au-delà du nombre de redirections autorisé" do
      stub_pages("boucle.fr" => redirect_response("https://boucle.fr/tarte"))

      expect { described_class.call("https://boucle.fr/tarte") }
        .to raise_error(Recipes::ExtractionError, "Trop de redirections")
      expect(page_requests.size).to eq(described_class::MAX_REDIRECTS + 1)
    end
  end

  # ── Type de contenu ─────────────────────────────────────────────────────

  describe "type de contenu" do
    it "refuse une réponse qui n'est pas du HTML, sans en lire le corps" do
      response = http_response(Net::HTTPOK, "200", body: "%PDF-1.4", headers: { "Content-Type" => "application/pdf" })
      stub_pages("exemple.fr" => response)

      expect { described_class.call("https://exemple.fr/recette.pdf") }
        .to raise_error(Recipes::ExtractionError, /ne pointe pas vers une page de recette/)
      expect(response).not_to have_received(:read_body)
    end

    it "accepte le XHTML" do
      stub_pages("exemple.fr" => page_response("<html></html>", headers: { "Content-Type" => "application/xhtml+xml" }))

      expect(described_class.call("https://exemple.fr/tarte")).to eq("<html></html>")
    end

    # Un serveur muet sur le type ne doit pas bloquer un import qui marchait :
    # le parseur en aval saura dire si ce n'est pas exploitable.
    it "tolère une réponse sans Content-Type" do
      stub_pages("exemple.fr" => http_response(Net::HTTPOK, "200", body: "<html></html>"))

      expect(described_class.call("https://exemple.fr/tarte")).to eq("<html></html>")
    end
  end

  # ── Taille de la page ───────────────────────────────────────────────────

  describe "taille de la page" do
    it "refuse une page dont la taille annoncée dépasse le plafond, sans lire le corps" do
      response = page_response("<html></html>", headers: { "Content-Length" => (described_class::MAX_BYTES + 1).to_s })
      stub_pages("exemple.fr" => response)

      expect { described_class.call("https://exemple.fr/tarte") }
        .to raise_error(Recipes::ExtractionError, "Cette page est trop volumineuse pour être importée")
      expect(response).not_to have_received(:read_body)
    end

    # Sans Content-Length (transfert en chunked), le dépassement ne se découvre
    # qu'en cours de lecture. Plafond abaissé pour ne pas allouer 3 Mo ici.
    it "interrompt la lecture d'une page trop volumineuse qui n'annonce pas sa taille" do
      stub_const("#{described_class}::MAX_BYTES", chunk_bytes)
      stub_pages("exemple.fr" => page_response("x" * (chunk_bytes * 3)))

      expect { described_class.call("https://exemple.fr/tarte") }
        .to raise_error(Recipes::ExtractionError, "Cette page est trop volumineuse pour être importée")
    end

    it "accepte une page dont la taille annoncée tient dans le plafond" do
      html = "<html><body>Tarte</body></html>"
      stub_pages("exemple.fr" => page_response(html, headers: { "Content-Length" => html.bytesize.to_s }))

      expect(described_class.call("https://exemple.fr/tarte")).to eq(html)
    end
  end

  # ── Pannes ──────────────────────────────────────────────────────────────

  describe "pannes" do
    it "signale un code de réponse non 200" do
      stub_pages("exemple.fr" => http_response(Net::HTTPNotFound, "404"))

      expect { described_class.call("https://exemple.fr/tarte") }
        .to raise_error(Recipes::ExtractionError, "URL inaccessible (code 404)")
    end

    it "enveloppe les erreurs réseau" do
      allow(Net::HTTP).to receive(:new).and_raise(SocketError, "getaddrinfo failed")

      expect { described_class.call("https://introuvable.fr/tarte") }
        .to raise_error(Recipes::ExtractionError, /Impossible d'accéder à l'URL : getaddrinfo failed/)
    end
  end
end
