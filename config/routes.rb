Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Defines the root path route ("/")
  root "locations#index"

  resources :geojson_imports, only: [:index, :new, :create]
  resources :locations, only: [:index] do
    collection do
      get :classifications
      get :classify
      patch 'classify/:id', to: 'locations#update_classification'
      get :gallery
      get :florida
      get :bulk_upload
      post :process_bulk_upload
    end
  end
end
