Rails.application.routes.draw do
  root "home#index"
  get "home/index"
  devise_for :users, controllers: { registrations: "users/registrations" }

  # Préférences du profil utilisateur
  resource :profile, only: [], controller: :profiles do
    get   :preferences
    patch :preferences, action: :update_preferences
  end

  # Foyer : les comptes qui partagent menus et liste de courses. Toujours celui
  # du compte connecté, d'où la ressource au singulier (pas d'id dans l'URL).
  resource :household, only: [ :show ], path: "foyer" do
    patch :renew_invitation  # Nouveau lien d'invitation — l'ancien cesse de fonctionner
    # Quitter le foyer (son propre id) ou en retirer un autre membre
    resources :members, only: [ :destroy ], path: "membres", module: :households
    # Les courses habituelles du foyer (UC8, étape 3)
    resources :usual_grocery_items, only: [ :index, :create, :update, :destroy ],
                                    path: "courses-habituelles", module: :households do
      # Reprendre les ajouts ponctuels d'une liste de courses (params: menu_id)
      post :import, on: :collection, path: "reprendre"
    end
  end

  # Lien d'invitation partagé par un membre : confirmation, puis entrée dans le foyer
  get  "foyer/rejoindre/:token", to: "households/invitations#show", as: :household_invitation
  post "foyer/rejoindre/:token", to: "households/invitations#create"

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
    resources :grocery_items, only: [ :create, :update, :destroy ] do
      # « Je m'en occupe » : prendre un article pour soi, ou le laisser
      member do
        patch  :claim, to: "grocery_claims#claim_item"
        delete :claim, to: "grocery_claims#release_item"
      end
      # … ou tout un rayon (params: category)
      collection do
        patch  :claim_section, to: "grocery_claims#claim_section"
        delete :claim_section, to: "grocery_claims#release_section"
        # Courses habituelles : la pop-up « Mes habituelles », puis l'ajout de ce qu'on y a retenu
        get    :usual, to: "usual_grocery_additions#new"
        post   :usual, to: "usual_grocery_additions#create"
      end
    end
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
