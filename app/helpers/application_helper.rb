module ApplicationHelper
  include Pagy::Frontend

  # Retourne un message d'accueil personnalisé et aléatoire
  # Délègue la logique au GreetingService pour une meilleure séparation des responsabilités
  # La phrase est stockée en session pour rester cohérente pendant toute la journée
  # Une nouvelle phrase est générée chaque jour pour garder le charme de la personnalisation
  def random_greeting(user)
    today = Date.today.to_s
    
    # Réinitialiser la phrase si on est un nouveau jour
    if session[:greeting_date] != today
      session[:greeting_date] = today
      session[:user_greeting] = GreetingService.new(user).random_greeting
    end
    
    session[:user_greeting]
  end

  # Vérifie si on est sur la page d'accueil
  def home_page?
    controller_name == 'home' && action_name == 'index'
  end
end
