# frozen_string_literal: true

# Vocabulaire partagé des unités de mesure.
#
# Une même cuillère à soupe s'écrit « càs », « c. à s. », « CS » ou « cuillère à
# soupe » selon qui parle : la recette qu'on photographie, l'IA qui la lit, le
# formulaire qui la corrige, la base qui la stocke. Ce module est le seul endroit
# du projet qui connaisse ces façons de dire — et le seul qui sache ce qu'elles
# valent.
#
# Trois vocabulaires, une seule table de vérité :
#
# - UNITS    : les unités canoniques. Sans accent ni ponctuation, ce sont elles
#              qui voyagent en base (Ingredient#base_unit), dans ai_raw_data,
#              dans les attributs data et dans le JSON envoyé à Stimulus.
# - ALIASES  : tout ce qu'on accepte de lire, ramené à une unité canonique. Les
#              clés sont déjà normalisées (cf. .normalize), d'où leur petit
#              nombre : « c. à s. », « C À S » et « càs » se ramènent tous à
#              « cas » sans qu'aucune de ces écritures figure ici.
# - AI_UNITS : le vocabulaire imposé à l'IA par le schéma de sortie. Délibérément
#              verbeux : « càc » et « càs » ne diffèrent que d'une lettre, et le
#              modèle les confondait — « 3 c. à s. d'huile d'olive » ressortait
#              en « 3 càc ». Diviser une quantité par trois passe inaperçu.
#
# Les libellés français vivent dans LABELS et pas dans fr.yml : une unité n'est
# pas du texte d'interface mais une valeur du domaine, qui doit se lire pareil
# dans une vue, dans un attribut data et dans un prompt.
module Units
  # unité canonique => groupe d'unités + facteur vers l'unité de base du groupe.
  # L'ordre compte : il pilote celui du sélecteur d'unités du formulaire de
  # recette, de la plus petite à la plus grande.
  UNITS = {
    "g"     => { unit_group: "mass",   factor: 1.0 },
    "kg"    => { unit_group: "mass",   factor: 1000.0 },
    "ml"    => { unit_group: "volume", factor: 1.0 },
    "cl"    => { unit_group: "volume", factor: 10.0 },
    "dl"    => { unit_group: "volume", factor: 100.0 },
    "l"     => { unit_group: "volume", factor: 1000.0 },
    "cac"   => { unit_group: "spoon",  factor: 1.0 },
    "cas"   => { unit_group: "spoon",  factor: 3.0 },
    "piece" => { unit_group: "count",  factor: 1.0 }
  }.freeze

  # Libellé français d'une unité, quand il diffère de la façon dont on la
  # stocke. Les autres s'écrivent comme leur symbole (g, kg, ml, cl, dl).
  LABELS = {
    "l"     => "L",
    "cac"   => "càc",
    "cas"   => "càs",
    "piece" => "pièce"
  }.freeze

  # Unité de base de chaque groupe : celle dont le facteur vaut 1, c'est-à-dire
  # celle dans laquelle les quantités sont stockées. Dérivée de UNITS plutôt que
  # recopiée — Ingredient::BASE_UNITS s'y branche.
  BASE_UNITS = UNITS.select { |_unit, data| data[:factor] == 1.0 }
                    .to_h { |unit, data| [ data[:unit_group], unit ] }
                    .freeze

  # Unité d'une quantité qui n'en porte pas : « 3 oeufs » se compte en pièces.
  # Une recette ne le dit jamais et l'IA laisse donc unit à null — c'est ici, et
  # non chez chaque appelant, que ce silence prend un sens.
  DEFAULT_UNIT = "piece"

  # Une cuillère est une mesure de volume : 1 càc = 5 ml, 1 càs = 15 ml, dans
  # toutes les cuisines. Le groupe `spoon` reste malgré tout distinct du volume,
  # parce que ce qu'on stocke n'est pas ce qu'on mesure : une épice, une sauce ou
  # du miel se comptent en cuillères (63 ingrédients du catalogue), une huile en
  # millilitres. C'est l'équivalence ci-dessous qui fait le pont entre les deux
  # façons de dire, dans les deux sens.
  ML_PER_CAC = 5.0

  # Équivalences universelles d'un groupe d'unités à l'autre : facteur appliqué
  # après le passage à l'unité de base du groupe de départ.
  #
  # « Universelles » est la condition d'entrée dans cette table : une cuillère à
  # soupe fait 15 ml quoi qu'on y mette. Passer au poids, lui, dépend de
  # l'ingrédient — une cuillère de farine et une cuillère de miel ne pèsent pas
  # le même poids — et relève donc de l'ingrédient lui-même
  # (Ingredient#piece_weight_g, cf. UnitConversionService), jamais d'ici.
  #
  # `offered` sépare deux gestes que rien n'oblige à être symétriques :
  #
  # - **lire** ce qu'une recette a écrit — on accepte tout ce qu'on sait
  #   convertir, y compris « 20 cl de sauce soja » pour une sauce comptée en
  #   cuillères : mieux vaut 40 càc qu'un refus ;
  # - **proposer** une unité à la saisie — là, offrir tout ce qu'on sait
  #   convertir invite à se tromper. « 2 càs d'huile » est la façon normale de
  #   doser une huile ; « 20 cl de curcuma » n'a aucun sens et ne doit pas
  #   figurer dans un sélecteur d'épice.
  #
  # D'où le sens unique : la cuillère est offerte aux liquides, le millilitre
  # n'est jamais offert à ce qui se compte en cuillères.
  EQUIVALENCES = {
    %w[spoon volume] => { factor: ML_PER_CAC,         offered: true },
    %w[volume spoon] => { factor: 1.0 / ML_PER_CAC,   offered: false }
  }.freeze

  # Formes acceptées en lecture => unité canonique. Clés déjà normalisées.
  # Volontairement limité à ce qui désigne vraiment une unité de mesure :
  # « tranches » ou « brins » n'en sont pas, et doivent continuer d'échouer pour
  # que la revue de l'import le signale au lieu de recopier le nombre.
  ALIASES = {
    "gramme" => "g", "grammes" => "g",
    "kilo" => "kg", "kilos" => "kg", "kilogramme" => "kg", "kilogrammes" => "kg",
    "millilitre" => "ml", "millilitres" => "ml",
    "centilitre" => "cl", "centilitres" => "cl",
    "decilitre" => "dl", "decilitres" => "dl",
    "litre" => "l", "litres" => "l",
    # Cuillère à soupe : « CS », « cuil. à soupe », « cuillères à soupe »,
    # « cuillere_a_soupe » (le jeton de l'IA), « tbsp ».
    "cs" => "cas", "cuilasoupe" => "cas", "cuillasoupe" => "cas",
    "cuillereasoupe" => "cas", "cuilleresasoupe" => "cas", "tbsp" => "cas",
    # Cuillère à café, dite aussi à thé.
    "cc" => "cac", "cuilacafe" => "cac", "cuillacafe" => "cac",
    "cuillereacafe" => "cac", "cuilleresacafe" => "cac",
    "cuillereathe" => "cac", "cuilleresathe" => "cac", "tsp" => "cac",
    "pieces" => "piece", "unite" => "piece", "unites" => "piece"
  }.freeze

  # Vocabulaire imposé à l'IA (enum du schéma de sortie). Chaque jeton se ramène
  # à une unité canonique par .canonical — units_spec le vérifie.
  AI_UNITS = %w[g kg ml cl L cuillere_a_soupe cuillere_a_cafe].freeze

  class << self
    # Unité canonique correspondant à une unité écrite, nil quand on ne sait pas
    # la lire (unité absente comprise : c'est à l'appelant de décider si le
    # silence vaut DEFAULT_UNIT — cf. .definition).
    #
    # @param unit [String, Symbol, nil]
    # @return [String, nil]
    def canonical(unit)
      key = normalize(unit)
      return nil if key.empty?

      UNITS.key?(key) ? key : ALIASES[key]
    end

    # Groupe d'unités et facteur d'une unité écrite ; nil si elle est illisible.
    # Une unité absente est un décompte (« 3 oeufs »).
    #
    # @param unit [String, Symbol, nil]
    # @return [Hash, nil] { unit_group:, factor: }
    def definition(unit)
      UNITS[unit.to_s.strip.empty? ? DEFAULT_UNIT : canonical(unit)]
    end

    # Libellé à afficher pour une unité, écrite comme on la stocke ou comme on
    # l'a lue. Une unité illisible s'affiche telle quelle : mieux vaut montrer
    # « 2 tranches » que de faire disparaître ce que la recette disait.
    #
    # @param unit [String, Symbol, nil]
    # @return [String]
    def label(unit)
      key = canonical(unit)
      return unit.to_s if key.nil?

      LABELS.fetch(key, key)
    end

    # Facteur menant d'une unité écrite à l'unité de base d'un groupe : ce par
    # quoi multiplier la quantité pour la stocker. nil quand rien d'universel ne
    # relie les deux — c'est alors à l'ingrédient de faire le pont, ou à personne.
    #
    #   factor_to("cl",  :volume) → 10.0    (même groupe)
    #   factor_to("cas", :volume) → 15.0    (1 càs = 3 càc = 15 ml)
    #   factor_to("cl",  :spoon)  → 2.0     (10 ml = 2 càc)
    #   factor_to("cas", :mass)   → nil     (dépend de l'ingrédient)
    #
    # @param unit [String, Symbol, nil]
    # @param unit_group [String, Symbol, nil]
    # @return [Float, nil]
    def factor_to(unit, unit_group)
      definition = definition(unit)
      return nil unless definition

      group = unit_group.to_s
      return definition[:factor] if definition[:unit_group] == group

      equivalence = EQUIVALENCES[[ definition[:unit_group], group ]]
      equivalence && definition[:factor] * equivalence[:factor]
    end

    # Unités qu'on propose à la saisie pour un ingrédient de ce groupe, prêtes
    # pour options_for_select : [[libellé, unité canonique]].
    #
    # Les unités du groupe d'abord, puis celles qu'une équivalence y ramène *et*
    # qu'on accepte de proposer (cf. EQUIVALENCES) : une huile se dose en
    # millilitres comme en cuillères, une épice en cuillères seulement.
    #
    # @param unit_group [String, Symbol, nil]
    # @return [Array<Array(String, String)>]
    def select_options(unit_group)
      group = unit_group.to_s
      own, others = UNITS.keys.partition { |unit| UNITS[unit][:unit_group] == group }
      bridged = others.select { |unit| offered?(UNITS[unit][:unit_group], group) }

      (own + bridged).map { |unit| [ label(unit), unit ] }
    end

    # Toutes les unités qu'on sait lire, prêtes pour options_for_select.
    #
    # Le pendant sans ingrédient de select_options : le formulaire d'ajout de la
    # liste de courses parle d'un article qui n'est pas forcément au catalogue,
    # et n'a donc aucun groupe d'unités à restreindre. Il les offre toutes
    # plutôt que d'en recopier une liste en dur dans la vue — c'est ainsi que le
    # centilitre et le décilitre y manquaient.
    #
    # @return [Array<Array(String, String)>]
    def all_select_options
      UNITS.keys.map { |unit| [ label(unit), unit ] }
    end

    # Propose-t-on de saisir une unité de ce groupe pour un ingrédient de
    # celui-là ? Réservé à select_options et à son miroir JS : la conversion,
    # elle, ne s'embarrasse pas de cette question (cf. factor_to).
    #
    # @return [Boolean]
    def offered?(from_group, to_group)
      EQUIVALENCES.dig([ from_group.to_s, to_group.to_s ], :offered) || false
    end

    # La table, prête à traverser vers Stimulus. Les deux contrôleurs qui
    # convertissent des unités (panneau IA, quantité d'une préparation) lisent
    # celle-ci : il n'existe pas de table de conversion en JS. Les équivalences
    # voyagent avec les unités, sinon le JS ne saurait pas non plus les composer.
    #
    # @return [Hash] { units: { "cas" => { unit_group:, factor:, label: } },
    #                  equivalences: { "spoon>volume" => { factor:, offered: } } }
    def table
      {
        units:        UNITS.to_h { |unit, data| [ unit, data.merge(label: label(unit)) ] },
        equivalences: EQUIVALENCES.to_h { |(from, to), data| [ "#{from}>#{to}", data ] }
      }
    end

    # Ramène une écriture à sa forme de comparaison : sans casse, sans accents,
    # sans ponctuation, sans espaces ni tirets bas. « C. à S. », « c à s »,
    # « càs » et « cuillere_a_soupe » se réduisent ainsi à trois clés au lieu
    # d'une par écriture possible.
    #
    # @param unit [String, Symbol, nil]
    # @return [String]
    def normalize(unit)
      I18n.transliterate(unit.to_s.downcase).gsub(/[^a-z0-9]/, "")
    end
  end
end
