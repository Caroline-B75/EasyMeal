Rails.application.routes.draw do
  root "home#index"
  get "home/index"
  devise_for :users, controllers: { registrations: 'users/registrations' }

  # Gestion des ingrédients
  resources :ingredients
  
  # Gestion des tags (admin only)
  resources :tags, except: [:show, :new, :create]
  
  # Gestion des recettes (UC4 - Fiche recette, UC5 - Catalogue)
  resources :recipes do
    # Actions sociales (UC4)
    member do
      post :toggle_favorite  # Toggle favori
      post :add_review       # Ajouter/modifier un avis
      delete :remove_review  # Supprimer son avis
    end
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
