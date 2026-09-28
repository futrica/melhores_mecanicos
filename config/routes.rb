Rails.application.routes.draw do
  devise_for :users, controllers: { omniauth_callbacks: "users/omniauth_callbacks", registrations: "users/registrations" }

  # ==========================================
  # 301 SEO Redirect for www Domain
  # ==========================================
  constraints ->(req) { req.host == "www.hospedagemdireta.com.br" } do
    match "*path", to: redirect(status: 301) { |_params, req| "https://hospedagemdireta.com.br#{req.fullpath}" }, via: :all
    root to: redirect("https://hospedagemdireta.com.br/", status: 301), as: nil
  end

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  get "up" => "rails/health#show", as: :rails_health_check

  # ==========================================
  # Logged-in Area /app
  # ==========================================
  namespace :app do
    root to: "home#index"

    post "approve_company/:id", to: "home#approve_company", as: :approve_company
    post "reject_company/:id", to: "home#reject_company", as: :reject_company

    resources :companies, only: [ :new, :create, :edit, :update ] do
      collection do
        get :cities
        get :neighborhoods
      end
      member do
        post :claim
        get :verify
        post :submit_verification
        delete :soft_delete
        delete :purge_photo
        post :update_card
        delete :remove_card
        post :cancel_subscription
      end
    end


    post "stop_impersonating", to: "/application#stop_impersonating", as: :stop_impersonating

    namespace :admin do
      get "/" => "dashboard#index", as: :dashboard
      resources :top_companies, only: [ :index, :show ] do
        member do
          post :send_email
        end
      end
      resources :companies, only: [ :index, :show ] do
        member do
          post :send_email
        end
      end
      resources :users, only: [ :index, :show ] do
        member do
          post :impersonate
        end
      end
      resources :contacts, only: [ :index, :show ]
      resources :outreach_logs, only: [ :index ]
    end
  end

  # Stripe Webhook
  post "webhooks/stripe", to: "webhooks/stripe#create"

  # Favorites toggle
  post "favorites/toggle/:company_id", to: "favorites#toggle", as: :toggle_favorite

  # Reviews & Contact Reveals
  resources :reviews, only: [ :destroy ]
  resources :companies, only: [] do
    resources :reviews, only: [ :create ]
    post :reveal_contact, to: "contact_reveals#create"
  end

  # Home page
  root "home#index"
  get "ads.txt", to: "home#ads_txt"
  get "sitemap_index.xml", to: "sitemaps#index", defaults: { format: "xml" }
  get "sitemap.xml", to: "sitemaps#index", defaults: { format: "xml" }
  get "sitemaps/:filename", to: "sitemaps#show", constraints: { filename: /[a-z0-9_]+\.xml/ }, defaults: { format: "xml" }

  # Institutional pages
  get "planos" => "pages#pricing", as: :pricing
  get "quem-somos" => "pages#about", as: :about
  get "termos-de-uso" => "pages#terms", as: :terms
  get "politica-de-privacidade" => "pages#privacy", as: :privacy
  get "contato" => "contacts#new", as: :contact
  post "contato" => "contacts#create", as: :contacts

  # Claim & Removal routes
  get "/reivindicar", to: "claims#new", as: :new_claim
  post "/reivindicar", to: "claims#create"
  get "/remover-perfil/:company_id", to: "removals#new", as: :new_removal
  post "/remover-perfil/:company_id", to: "removals#create", as: :removals

  # Outreach click tracking route
  get "outreach/click/:token", to: "outreach_clicks#show", as: :outreach_click

  # Unsubscribe / Opt-Out routes
  get "descadastrar/:token", to: "unsubscribes#show", as: :unsubscribe
  post "descadastrar/:token", to: "unsubscribes#create"

  # Company details (legacy/redirect support)
  get "empresa/:slug" => "companies#show"

  # Search routes
  get "busca" => "search#index", as: :search
  get "api/cities" => "search#cities"
  get "api/neighborhoods" => "search#neighborhoods"

  # Locations catch-all (Must be at the bottom to avoid clashing with other routes)
  get ":state_slug" => "locations#state", as: :state_page
  get ":state_slug/:city_slug" => "locations#city", as: :city_page
  get ":state_slug/:city_slug/:neighborhood_slug" => "locations#neighborhood", as: :neighborhood_page
  get ":state_slug/:city_slug/:neighborhood_slug/:slug" => "companies#show", as: :company_page
end
