# Service pour gérer les messages d'accueil personnalisés
# Gère les variations de genre pour les adjectifs
class GreetingService
  GREETINGS = [
    "Bonjour %{name}, qu'est-ce qu'on mange ce soir ?",
    "Hello %{name} ! %{ready} à mitonner de bons petits plats ?",
    "Coucou %{name}, une petite faim ?",
    "Hey %{name} ! Envie de cuisiner aujourd'hui ?",
    "Bonjour %{name} ! Ta cuisine t'attend...",
    "Hello %{name}, et si on composait un menu aux petits oignons ?",
    "Salut %{name} ! L'inspiration culinaire frappe à ta porte...",
    "%{name}, %{ready} à épater tes papilles ?",
    
    # Nouvelles phrases
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

  def initialize(user)
    @user = user
  end

  # Retourne un message d'accueil aléatoire personnalisé
  def random_greeting
    greeting_template = GREETINGS.sample
    greeting_template % greeting_variables
  end

  private

  # Variables à injecter dans les templates de phrases
  def greeting_variables
    {
      name: user_first_name,
      ready: gendered_adjective('prêt', 'prête'),
      hot: gendered_adjective('chaud bouillant', 'chaude bouillante'),
      alone: gendered_adjective('tout seul', 'toute seule')
    }
  end

  # Retourne l'adjectif accordé selon le genre de l'utilisateur
  # @param masculine [String] forme masculine
  # @param feminine [String] forme féminine
  # @return [String] forme genrée ou neutre
  def gendered_adjective(masculine, feminine)
    case @user.gender
    when 'male'
      masculine
    when 'female'
      feminine
    else
      "#{masculine}(e)" # Format neutre si genre non spécifié
    end
  end

  # Extrait le prénom de l'utilisateur ou génère un nom à partir de l'email
  def user_first_name
    @user.first_name.presence || @user.email.split('@').first.capitalize
  end
end
