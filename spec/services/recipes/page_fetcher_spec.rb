# frozen_string_literal: true

require "rails_helper"

# Spec de Recipes::PageFetcher, extrait d'ExtractorService : ces exemples
# étaient auparavant écrits contre ExtractorService#fetch_html, atteint par
# `send` ou indirectement via .from_url. La classe étant maintenant autonome,
# ils l'appellent directement.
#
# Aucun appel réseau réel n'est fait : ni webmock ni vcr ne sont au Gemfile, on
# intercepte donc Net::HTTP.new pour router chaque connexion vers une réponse
# simulée (voir #stub_pages).
RSpec.describe Recipes::PageFetcher do
  # Requêtes GET reçues, pour inspecter le chemin et les en-têtes envoyés.
  let(:page_requests) { [] }

  # Réseau scellé par défaut : toute connexion non explicitement simulée par
  # l'exemple lève une erreur bruyante.
  before { stub_pages({}) }

  # Intercepte Net::HTTP.new et route chaque connexion selon l'hôte appelé.
  # @param pages [Hash] { "exemple.fr" => réponse Net::HTTP }
  def stub_pages(pages)
    allow(Net::HTTP).to receive(:new) do |host, _port|
      connection = instance_double(
        Net::HTTP, :use_ssl= => nil, :open_timeout= => nil, :read_timeout= => nil
      )

      allow(connection).to receive(:get) do |path, headers|
        page_requests << { host: host, path: path, headers: headers }
        pages.fetch(host) { raise "Requête HTTP non simulée dans cet exemple : GET #{host}" }
      end

      connection
    end
  end

  # Fabrique une vraie réponse Net::HTTP : c'est sa *classe* qui porte la
  # famille (succès / redirection / erreur) que le service teste par `case`.
  def http_response(klass, code, body: "", location: nil)
    response = klass.new("1.1", code, code)
    # Le corps est dupliqué : le fetcher appelle force_encoding, qui mute.
    allow(response).to receive(:body).and_return(body.dup)
    allow(response).to receive(:[]).with("location").and_return(location)
    response
  end

  def page_response(html)
    http_response(Net::HTTPOK, "200", body: html)
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
        "ancien.fr"  => http_response(Net::HTTPMovedPermanently, "301", location: "https://nouveau.fr/tarte"),
        "nouveau.fr" => page_response("<html><body>Tarte</body></html>")
      )

      expect(described_class.call("https://ancien.fr/tarte")).to eq("<html><body>Tarte</body></html>")
      expect(page_requests.map { |request| request[:host] }).to eq([ "ancien.fr", "nouveau.fr" ])
    end

    # Chaque saut repasse par la validation : une redirection ne peut pas faire
    # sortir du web (javascript:, file:, ftp:…).
    it "applique la validation du schéma à la destination d'une redirection" do
      stub_pages(
        "exemple.fr" => http_response(Net::HTTPFound, "302", location: "ftp://exemple.fr/tarte")
      )

      expect { described_class.call("https://exemple.fr/tarte") }
        .to raise_error(Recipes::ExtractionError, "URL invalide (doit commencer par http/https)")
    end

    it "abandonne au-delà du nombre de redirections autorisé" do
      stub_pages(
        "boucle.fr" => http_response(Net::HTTPFound, "302", location: "https://boucle.fr/tarte")
      )

      expect { described_class.call("https://boucle.fr/tarte") }
        .to raise_error(Recipes::ExtractionError, "Trop de redirections")
      expect(page_requests.size).to eq(described_class::MAX_REDIRECTS + 1)
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
