Rails.application.routes.draw do
  # For details on the DSL available within this file, see http://guides.rubyonrails.org/routing.html

  # The priority is based upon order of creation: first created -> highest priority.
  # See how all your routes lay out with "rails routes".

  root 'home#index'

  namespace :admin do
    root 'home#index'
    resources :elections do
      member do
        get 'duplicate'
        post 'post_duplicate'
        get 'analytics'
        get 'analytics_more'
        get 'analytics_cooccurrence'
        get 'analytics_adjustable_cost_projects'
        get 'analytics_chicago49'
        get 'to_voting_machine'
        post 'post_to_voting_machine'
      end
      collection do
        get 'config_reference'
      end
      resources :projects do
        collection do
          patch 'reorder'
          get 'import'
          post 'post_import'
          get 'export'
        end
      end
      resources :categories do
        collection do
          patch 'reorder'
        end
      end
      resources :users do
        member do
          delete 'election_user_destroy'
          get 'resend_confirmation'
        end
      end
      resources :code_batches do
        collection do
          get 'import'
          post 'post_import'
        end
      end
      resources :locations
      resources :voters
      resources :voter_registration_records
      resources :files, id: /[^\/]+/
    end
    resources :users do
      collection do
        get 'login'
        post 'post_login'
        get 'logout'
        get 'reset_password'
        post 'post_reset_password'
        get 'reset_password_email_sent'
        get 'profile'
        get 'edit_profile'
        patch 'update_profile'
        get 'edit_password'
        patch 'update_password'
      end
      member do
        get 'validate_confirmation'
        post 'set_password'
        get 'resend_confirmation'
      end
    end

    if Rails.env.production?
      # Show the fake 'no access' page to prevent an attacker from figuring out the website's structure
      match '*path', to: 'home#fake_no_access', via: :all
    end
  end

  post 'contact' => 'home#contact'
  get 'done_survey' => 'home#done_survey'
  get 'terms' => 'home#terms'
  post 'twilio_sms' => 'home#twilio_sms'

  get ':election_slug(/:action(/:id))', controller: 'vote'
  post ':election_slug(/:action(/:id))', controller: 'vote'
  patch ':election_slug(/:action(/:id))', controller: 'vote'
end
