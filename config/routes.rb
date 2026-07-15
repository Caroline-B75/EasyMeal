Rails.application.routes.draw do
  root "home#index"
  get "home/index"
  devise_for :users, controllers: { registrations: "users/registrations" }

  # Gestion des ingrédients
  resources :ingredients do
    collection do
      post :quick_create  # Création rapide depuis le formulaire recette
    end
    member do
      patch :add_alias    # Ajoute un alias à un ingrédient (confirmation match IA)
    end
  end

  # Gestion des tags (admin only)
  resources :tags, except: [ :show, :new, :create ]

  # Gestion des menus (UC1, UC2, UC3)
  resources :menus do
    member do
      post :activate            # UC1 : Valider le menu brouillon → génère la liste de courses
      post :reactivate          # Réactiver un menu archivé (remplace le menu actif courant)
      post :revert_to_draft    # R3.2bis : Repasser un menu actif en brouillon pour le modifier
      post :add_random_meal    # UC2 : Ajouter un repas aléatoire au menu
      post :replace_meal       # UC2 : Remplacer un repas (params: menu_recipe_id)
      get  :grocery                   # UC3 : Page dédiée de la liste de courses
      post :regenerate_grocery       # UC3 : Régénérer la liste de courses
      post :regenerate               # UC2 : Re-générer le menu brouillon avec de nouveaux paramètres
    end
    resources :menu_recipes, only: [ :create, :update, :destroy ] do
      collection do
        patch :reorder
      end
    end
    resources :grocery_items, only: [ :create, :update, :destroy ]
  end

  # Recettes brouillons (admin only — import IA en attente de validation)
  resources :recipe_drafts, only: [ :index, :destroy ]

  # Import IA de recettes (admin only — URL ou photo)
  resources :recipe_imports, only: [ :new, :create ]

  # Gestion des recettes (UC4 - Fiche recette, UC5 - Catalogue)
  resources :recipes do
    # Actions sociales (UC4)
    member do
      post  :toggle_favorite  # Toggle favori
      post  :toggle_in_draft  # UC2 : Toggle ajout/retrait de la recette dans le menu brouillon
      patch :publish          # Publie un brouillon IA (admin only)
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

  # Page de secours hors-ligne pré-cachée par le service worker.
  get "offline" => "pwa#offline", as: :pwa_offline

  # Raccourcis PWA — cibles stables pour les "shortcuts" du manifest.
  # Le manifest est partagé et mis en cache : ses URLs ne peuvent pas dépendre
  # de l'utilisateur. Ces actions résolvent le menu actif côté serveur puis redirigent.
  get "menu-en-cours"    => "shortcuts#current_menu",    as: :current_menu_shortcut
  get "liste-de-courses" => "shortcuts#current_grocery", as: :current_grocery_shortcut

  # Defines the root path route ("/")
  # root "posts#index"
end
