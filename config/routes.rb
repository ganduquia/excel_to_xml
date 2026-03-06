Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  root "converter#index"
  post "/converter/upload", to: "converter#upload", as: :converter_upload
  get  "/converter/download/:filename", to: "converter#download", as: :converter_download

  namespace :taxes do
    # Documentos contables
    resources :documents, only: %i[index show create update destroy] do
      member do
        post :liquidate
        post :cancel
      end
    end

    # Tarifas IVA / ReteIVA / ReteICA parametrizables
    resources :tax_rates, only: %i[index show create update destroy] do
      collection { get :active }
    end

    # Conceptos de retención en la fuente
    resources :withholding_concepts, only: %i[index show create update destroy] do
      collection { get :applicable }
    end
  end
end
