Rails.application.routes.draw do
  root "home#index"
  get "home/index"
  devise_for :users, controllers: { registrations: "users/registrations" }

  # Gestion des ingrédients
  resources :ingredients do
    collection do
      post :quick_create  # Création rapide depuis le formulaire recette
    end
  end

  # Gestion des tags (admin only)
  resources :tags, except: [ :show, :new, :create ]

  # Gestion des menus (UC1, UC2, UC3)
  resources :menus do
    member do
      post :activate            # UC1 : Valider le menu brouillon → génère la liste de courses
      post :reactivate          # Réactiver un menu archivé (remplace le menu actif courant)
      post :add_random_meal    # UC2 : Ajouter un repas aléatoire au menu
      post :replace_meal       # UC2 : Remplacer un repas (params: menu_recipe_id)
      post :regenerate_grocery # UC3 : Régénérer la liste de courses
    end
    resources :menu_recipes, only: [ :create, :update, :destroy ]
    resources :grocery_items, only: [ :create, :update, :destroy ]
  end

  # Gestion des recettes (UC4 - Fiche recette, UC5 - Catalogue)
  resources :recipes do
    # Actions sociales (UC4)
    member do
      post :toggle_favorite  # Toggle favori
      post :add_to_menu      # UC2 : Ajouter la recette au menu brouillon en cours
    end
    # Avis (UC4) — gérés par Recipes::ReviewsController
    resources :reviews, only: [ :create, :destroy ], module: :recipes
  end

  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/*
  get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker
  get "manifest" => "rails/pwa#manifest", as: :pwa_manifest

  # Defines the root path route ("/")
  # root "posts#index"
end
