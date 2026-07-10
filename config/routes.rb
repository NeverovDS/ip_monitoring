require "sidekiq/web"

Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check

  # JSON API — kept from the Roda version, isolated in its own versioned
  # namespace instead of sharing controllers with the HTML UI via respond_to.
  namespace :api do
    namespace :v1 do
      resources :ips, only: %i[index show create destroy] do
        member do
          post :enable
          post :disable
          get :stats
        end
      end
    end
  end

  # Sidekiq dashboard (Basic Auth applied in config/initializers/sidekiq.rb).
  mount Sidekiq::Web => "/sidekiq"

  # HTML web UI.
  resources :ips do
    member do
      post :enable
      post :disable
      get :stats
      get :summary # compact last-hour RTT, loaded lazily into each list row
    end
  end

  root "ips#index"
end
