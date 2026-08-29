Rails.application.routes.draw do
  root "home#index"
  get "home/index"
  devise_for :users, controllers: { registrations: "users/registrations" }

  # Préférences du profil utilisateur
  resource :profile, only: [], controller: :profiles do
    get   :preferences
    patch :preferences, action: :update_preferences
  end

  # Gestion des ingrédients
  resources :ingredients do
    collection do
      post :quick_create  # Création rapide depuis le formulaire recette
      get  :search        # Recherche JSON (association manuelle depuis le panneau IA)
    end
    member do
      patch :add_alias    # Ajoute un alias à un ingrédient (confirmation match IA)
    end
  end

  # Gestion des tags (admin only)
  resources :tags, except: [ :show, :new ]

  # Gestion des utilisateurs (admin only)
  resources :users, only: [ :index, :edit, :update, :destroy ]

  # Gestion des menus (UC1, UC2, UC3)
  resources :menus do
    member do
      post :activate            # UC1 : Valider le menu brouillon → génère la liste de courses
      post :reactivate          # Réactiver un menu archivé (remplace le menu actif courant)
      post :revert_to_draft    # R3.2bis : Repasser un menu actif en brouillon pour le modifier
      post :replace_meal       # UC2 : Remplacer un repas (params: menu_recipe_id)
      get  :grocery                   # UC3 : Page dédiée de la liste de courses
      post :regenerate_grocery       # UC3 : Régénérer la liste de courses
      post :regenerate               # UC2 : Re-générer le menu brouillon avec de nouveaux paramètres
      patch :adjust_meal_count       # UC7 : + / − sur un moment, depuis le panneau de réglages du brouillon
    end
    resources :menu_recipes, only: [ :update, :destroy ] do
      collection do
        patch :reorder
      end
      member do
        patch :move_up    # UC7 : réordonner dans sa section (boutons mobiles ⬆️)
        patch :move_down  # UC7 : réordonner dans sa section (boutons mobiles ⬇️)
        post  :duplicate  # UC7 : répéter un repas — la copie se pose juste après lui
      end
    end
    resources :grocery_items, only: [ :create, :update, :destroy ]
  end

  # Recettes brouillons (admin only — import IA en attente de validation)
  resources :recipe_drafts, only: [ :index, :destroy ]

  # Import IA de recettes (admin only — URL ou photo). Le show est la page
  # d'attente : elle suit l'avancement du job d'extraction.
  resources :recipe_imports, only: [ :new, :create, :show ]

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

  # UC2 : retrait d'un repas (MenuRecipe) via la croix du rail « menu à valider »
  # du catalogue. Route distincte de menus/:menu_id/menu_recipes/:id : la réponse
  # est taillée pour le catalogue (rail + bouton de carte), pas pour la page du menu.
  delete "recipes/draft_meals/:id", to: "recipes#remove_from_draft", as: :recipes_draft_meal

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
