# frozen_string_literal: true

# Pages HTML de recette servant de fixtures aux specs d'import IA.
#
# Partagées par SchemaOrgParser — qui les lit — et par ExtractorService — qui
# l'orchestre : une seule définition pour les deux. spec/support n'étant pas
# chargé automatiquement, les specs concernées la requièrent explicitement.
module RecipePageFixtures
  # Nœud schema.org tel qu'un site le publie vraiment : libellés à espaces
  # parasites, durées ISO 8601, rendement exprimé en intervalle, étapes en
  # HowToStep.
  def schema_recipe
    {
      "@type"              => "Recipe",
      "name"               => "  Tarte aux poireaux  ",
      "description"        => "  Une tarte salée de saison  ",
      "recipeYield"        => "4-6 personnes",
      "prepTime"           => "PT20M",
      "cookTime"           => "PT40M",
      "totalTime"          => "PT1H",
      "recipeCategory"     => "Plat principal, Tarte",
      "recipeInstructions" => [
        { "@type" => "HowToStep", "text" => "Préchauffer le four." },
        { "@type" => "HowToStep", "text" => "Enfourner 40 minutes." }
      ],
      "recipeIngredient"   => []
    }
  end

  # Page portant un ou plusieurs blocs JSON-LD. Chaque bloc accepte un Hash ou
  # un Array (sérialisés), ou une chaîne brute pour simuler un JSON-LD invalide.
  def page_with_json_ld(*blocks)
    scripts = blocks.map do |data|
      payload = data.is_a?(String) ? data : data.to_json
      %(<script type="application/ld+json">#{payload}</script>)
    end

    <<~HTML
      <html>
        <head>#{scripts.join}</head>
        <body><h1>Soupe de potiron</h1><p>Faire revenir le potiron.</p></body>
      </html>
    HTML
  end

  # Forme @graph : un objet racine encapsulant tout le contenu de la page.
  def page_with_graph(recipe)
    page_with_json_ld({ "@context" => "https://schema.org",
                        "@graph"   => [ { "@type" => "WebPage" }, recipe ] })
  end

  # Page sans JSON-LD, avec du bruit (script, style, nav, footer) que
  # SchemaOrgParser.extract_text doit retirer avant de soumettre le texte à l'IA.
  def page_without_json_ld
    <<~HTML
      <html>
        <head><script>var analytics = 1;</script><style>.a { color: red; }</style></head>
        <body>
          <nav>Accueil Recettes Connexion</nav>
          <h1>Soupe de potiron</h1>
          <p>Faire revenir le potiron.</p>
          <footer>Mentions legales</footer>
        </body>
      </html>
    HTML
  end
end
