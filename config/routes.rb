Rails.application.routes.draw do
  resource :session
  resource :registration, only: %i[ new create ]
  resources :passwords, param: :token
  get "verify_email/:token", to: "email_verifications#show", as: :email_verification
  post "verify_email", to: "email_verifications#create", as: :email_verifications

  resources :themes, param: :name, only: %i[ index show ] do
    member do
      post :try
    end
  end
  delete "try", to: "themes#stop_trying", as: :stop_trying

  get "authors/:username", to: "authors#show", as: :author

  resource :dashboard, only: :show
  resources :submissions, only: %i[ new create ]
  get "guide", to: "guides#show"

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  root "themes#index"
end
