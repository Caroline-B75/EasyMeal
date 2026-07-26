# Service pour gérer les messages d'accueil personnalisés.
# Les paires changent chaque jour, mais restent choisies dans le contexte métier
# courant pour ne jamais annoncer une liste de courses indisponible.
class GreetingService
  # Structure de données retournée par #random_greeting
  Greeting = Struct.new(:text, :subtext)

  GREETING_TEXTS = [
    "Bonjour %{name}, qu'est-ce qu'on mange ce soir ?",
    "Hello %{name} ! %{ready} à mitonner de bons petits plats ?",
    "Coucou %{name}, une petite faim ?",
    "Hey %{name} ! Envie de cuisiner aujourd'hui ?",
    "Bonjour %{name} ! Ta cuisine t'attend...",
    "Hello %{name}, et si on composait un menu aux petits oignons ?",
    "Salut %{name} ! L'inspiration culinaire frappe à ta porte...",
    "%{name}, %{ready} à épater tes papilles ?",
    "Salut %{name} ! On met les petits plats dans les grands ?",
    "Coucou %{name}, c'est l'heure de mettre la main à la pâte !",
    "Hello %{name} ! Mijotons quelque chose ensemble !",
    "Salut %{name} ! On va se régaler aujourd'hui !",
    "Hey %{name} ! %{ready} pour un festin ?",
    "Salut %{name} ! On cuisine quoi ce soir ?",
    "Hello %{name}, ton frigo attend tes talents !",
    "Bonjour %{name} ! Et si on se faisait un bon petit plat ?",
    "Salut %{name} ! Spoiler : ça va être délicieux",
    "Coucou %{name}, chef en herbe ou chef confirmé aujourd'hui ?",
    "Hey %{name} ! Ton estomac dit merci d'avance.",
    "Hey %{name} ! Au menu aujourd'hui ?",
    "Coucou %{name}, on cuisine ?",
    "Coucou %{name}, ton talent culinaire est réclamé !",
    "Hey %{name} ! Ta cuisine te supplie de revenir !",
    "Salut %{name} ! Aujourd'hui, on évite les pâtes au beurre ?",
    "Bonjour %{name}, Gordon Ramsay n'a qu'à bien se tenir !",
    "Hey %{name} ! Entre nous, ce sera délicieux ET rapide !",
    "Bonjour %{name}, t'es %{hot} aujourd'hui ?",
    "Salut %{name} ! On va faire mijoter tout ça",
    "Hey %{name} ! C'est pas de la tarte... ou peut-être que si ?",
    "Salut %{name} ! Level up culinaire en cours...",
    "Hey %{name} ! Masterchef ou pas, on gère !",
    "Allez %{name} ! On va montrer de quoi on est capable !",
    "Allez %{name} ! On envoie de la qualité !",
    "Bonjour %{name} ! Aujourd'hui, on fait de la VRAIE cuisine !",
    "Salut %{name} ! Même Etchebest serait fier de toi aujourd'hui !",
    "Salut %{name} ! Pas besoin d'Etchebest, tu gères %{alone} !",
    "Hey %{name} ! Si Etchebest voyait ça, il dirait : putain c'est bon !",
    "Hey %{name} ! Etchebest called, il veut ta recette !",
    "Allez %{name} ! Montre à Etchebest ce que tu sais faire !"
  ].freeze

  CONTEXT_SUBTEXTS = {
    grocery_list_ready: [
      "Ta liste de courses est prête pour ton menu validé.",
      "Tout est prêt pour passer des idées aux courses.",
      "Le menu est validé, la liste de courses t'attend.",
      "Les recettes sont choisies et la liste est déjà là.",
      "Tu peux consulter la liste ou préparer le prochain menu."
    ],
    active_menu_ready: [
      "Ton menu est validé. Tu peux le consulter ou préparer le prochain.",
      "Ton menu est en place, prêt à guider les prochains repas.",
      "Les recettes sont validées, il ne reste qu'à passer en cuisine.",
      "Ton planning repas est calé pour la semaine.",
      "Tu peux garder ce menu ou commencer à imaginer la suite."
    ],
    pending_revalidation: [
      "Revalide tes modifications pour mettre à jour la liste de courses.",
      "Tes ajustements attendent validation avant de rafraîchir les courses.",
      "Encore une validation et la liste suivra tes nouvelles envies.",
      "Le menu est en retouche : revalide-le pour recalculer les courses.",
      "Tes changements sont prêts, la liste sera mise à jour après validation."
    ],
    draft_ready: [
      "Valide ce menu pour générer la liste de courses.",
      "Encore un petit feu vert et EasyMeal prépare les courses.",
      "Ton menu prend forme, il ne manque plus que la validation.",
      "Les recettes sont là : valide le menu pour passer aux courses.",
      "Ajuste les derniers détails, puis génère ta liste de courses."
    ],
    planning: [
      "Génère un menu, puis EasyMeal préparera ta liste de courses.",
      "Quelques idées bien choisies, et la semaine devient plus simple.",
      "Compose ton menu et laisse EasyMeal organiser la suite.",
      "Le bon repas du soir commence toujours par un bon menu.",
      "Choisis l'inspiration du moment, on s'occupe du reste après validation."
    ]
  }.freeze

  def initialize(user, context: :planning)
    @user = user
    @context = context.to_sym
  end

  # Retourne un Greeting(text:, subtext:) aléatoire et personnalisé
  def random_greeting
    text_template, subtext = greeting_pairs.sample
    Greeting.new(
      text_template % greeting_variables,
      subtext
    )
  end

  private

  def greeting_pairs
    subtexts = CONTEXT_SUBTEXTS.fetch(@context, CONTEXT_SUBTEXTS[:planning])

    GREETING_TEXTS.each_with_index.map do |text_template, index|
      [text_template, subtexts[index % subtexts.size]]
    end
  end

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
