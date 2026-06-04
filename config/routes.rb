Rails.application.routes.draw do
  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  namespace :api do
    namespace :v1 do
      defaults format: :json do
        resource :dashboard, only: :show, controller: "dashboard"
        resource :performance, only: :show, controller: "performance"
        resources :market_snapshots, only: :index
        resources :trade_signals, only: :index
        resources :orders, only: :index
        resources :activity_logs, only: :index
        resources :positions, only: %i[index create]
        resources :signals, only: :create
        resource :execution, only: :show, controller: "execution"
        resource :statistics, only: :show
        resources :position_updates, only: :create
        resources :order_updates, only: :create
      end
    end
  end
end
