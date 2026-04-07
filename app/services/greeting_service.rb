# Service pour gérer les messages d'accueil personnalisés
# Gère les variations de genre pour les adjectifs
# Chaque entrée est une paire [texte_principal, sous_texte]
class GreetingService
  # Structure de données retournée par #random_greeting
  Greeting = Struct.new(:text, :subtext)

  GREETING_PAIRS = [
    [ "Bonjour %{name}, qu'est-ce qu'on mange ce soir ?",
      "Un menu bien pensé, c'est déjà la moitié du travail." ],
    [ "Hello %{name} ! %{ready} à mitonner de bons petits plats ?",
      "Tes recettes préférées n'attendent que toi." ],
    [ "Coucou %{name}, une petite faim ?",
      "EasyMeal a quelques idées pour toi." ],
    [ "Hey %{name} ! Envie de cuisiner aujourd'hui ?",
      "On a sélectionné des recettes de saison rien que pour toi." ],
    [ "Bonjour %{name} ! Ta cuisine t'attend...",
      "Un peu d'inspiration et hop, c'est parti." ],
    [ "Hello %{name}, et si on composait un menu aux petits oignons ?",
      "Laisse EasyMeal faire le travail, toi tu régales." ],
    [ "Salut %{name} ! L'inspiration culinaire frappe à ta porte...",
      "Ouvre-lui, ça sent bon là-dedans." ],
    [ "%{name}, %{ready} à épater tes papilles ?",
      "Le bon repas du soir commence toujours par un bon menu." ],
    [ "Salut %{name} ! On met les petits plats dans les grands ?",
      "Tu as tout ce qu'il faut pour un repas mémorable." ],
    [ "Coucou %{name}, c'est l'heure de mettre la main à la pâte !",
      "On s'occupe du menu, tu t'occupes du reste." ],
    [ "Hello %{name} ! Mijotons quelque chose ensemble !",
      "De belles recettes de saison t'attendent." ],
    [ "Salut %{name} ! On va se régaler aujourd'hui !",
      "Le menu idéal est à portée de clic." ],
    [ "Hey %{name} ! %{ready} pour un festin ?",
      "EasyMeal est prêt si tu l'es." ],
    [ "Salut %{name} ! On cuisine quoi ce soir ?",
      "Un menu complet en quelques secondes, promis." ],
    [ "Hello %{name}, ton frigo attend tes talents !",
      "La liste de courses qui va avec est déjà là." ],
    [ "Bonjour %{name} ! Et si on se faisait un bon petit plat ?",
      "Quelques clics suffisent pour bien manger toute la semaine." ],
    [ "Salut %{name} ! Spoiler : ça va être délicieux",
      "Les recettes de saison sont au top en ce moment." ],
    [ "Coucou %{name}, chef en herbe ou chef confirmé aujourd'hui ?",
      "Dans tous les cas, EasyMeal est là pour t'aider." ],
    [ "Hey %{name} ! Ton estomac dit merci d'avance.",
      "Un bon menu, c'est un bon moral. On y va ?" ],
    [ "Hey %{name} ! Au menu aujourd'hui ?",
      "Génère ton menu et laisse EasyMeal s'occuper des courses." ],
    [ "Coucou %{name}, on cuisine ?",
      "C'est la meilleure décision de la journée." ],
    [ "Coucou %{name}, ton talent culinaire est réclamé !",
      "Tes papilles (et celles de ta famille) comptent sur toi." ],
    [ "Hey %{name} ! Ta cuisine te supplie de revenir !",
      "Elle a des recettes à te chuchoter." ],
    [ "Salut %{name} ! Aujourd'hui, on évite les pâtes au beurre ?",
      "EasyMeal a des propositions bien plus gourmandes." ],
    [ "Bonjour %{name}, Gordon Ramsay n'a qu'à bien se tenir !",
      "Ton menu cette semaine va impressionner tout le monde." ],
    [ "Hey %{name} ! Entre nous, ce sera délicieux ET rapide !",
      "Les meilleures recettes ne sont pas forcément les plus longues." ],
    [ "Bonjour %{name}, t'es %{hot} aujourd'hui ?",
      "Alors profites-en pour composer un menu de champion." ],
    [ "Salut %{name} ! On va faire mijoter tout ça",
      "Prends le temps de bien choisir, le résultat en vaut la peine." ],
    [ "Hey %{name} ! C'est pas de la tarte... ou peut-être que si ?",
      "On a justement quelques tartes de saison à te proposer." ],
    [ "Salut %{name} ! Level up culinaire en cours...",
      "Chaque menu est une nouvelle occasion de se régaler." ],
    [ "Hey %{name} ! Masterchef ou pas, on gère !",
      "EasyMeal s'adapte à tous les niveaux." ],
    [ "Allez %{name} ! On va montrer de quoi on est capable !",
      "Un menu bien planifié, c'est déjà à moitié réussi." ],
    [ "Allez %{name} ! On envoie de la qualité !",
      "Recettes soigneusement choisies, liste de courses incluse." ],
    [ "Bonjour %{name} ! Aujourd'hui, on fait de la VRAIE cuisine !",
      "Les produits de saison sont de ton côté." ],
    [ "Salut %{name} ! Même Etchebest serait fier de toi aujourd'hui !",
      "Alors vas-y, compose ton menu sans complexe." ],
    [ "Salut %{name} ! Pas besoin d'Etchebest, tu gères %{alone} !",
      "La preuve : EasyMeal te fait confiance." ],
    [ "Hey %{name} ! Si Etchebest voyait ça, il dirait : putain c'est bon !",
      "Allez, construis ce menu qui va tout déchirer." ],
    [ "Hey %{name} ! Etchebest called, il veut ta recette !",
      "Tu sais ce qui te reste à faire." ],
    [ "Allez %{name} ! Montre à Etchebest ce que tu sais faire !",
      "Les recettes de saison sont prêtes. À toi de jouer." ]
  ].freeze

  def initialize(user)
    @user = user
  end

  # Retourne un Greeting(text:, subtext:) aléatoire et personnalisé
  def random_greeting
    text_template, subtext = GREETING_PAIRS.sample
    Greeting.new(
      text_template % greeting_variables,
      subtext
    )
  end

  private

  # Variables à injecter dans les templates de phrases
  def greeting_variables
    {
      name: user_first_name,
      ready: gendered_adjective("prêt", "prête"),
      hot: gendered_adjective("chaud bouillant", "chaud bouillant"),
      alone: gendered_adjective("tout seul", "toute seule")
    }
  end

  # Retourne l'adjectif accordé selon le genre de l'utilisateur
  # @param masculine [String] forme masculine
  # @param feminine [String] forme féminine
  # @return [String] forme genrée ou neutre
  def gendered_adjective(masculine, feminine)
    case @user.gender
    when "male"
      masculine
    when "female"
      feminine
    else
      "#{masculine}(e)" # Format neutre si genre non spécifié
    end
  end

  # Extrait le prénom de l'utilisateur ou génère un nom à partir de l'email
  def user_first_name
    @user.first_name.presence || @user.email.split("@").first.capitalize
  end
end
