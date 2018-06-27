Rails.application.routes.draw do
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
      resources :code_batches
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

  get ':election_slug(/:action(/:id))', controller: 'vote'
  post ':election_slug(/:action(/:id))', controller: 'vote'
  patch ':election_slug(/:action(/:id))', controller: 'vote'

  # The priority is based upon order of creation: first created -> highest priority.
  # See how all your routes lay out with "rake routes".

  # You can have the root of your site routed with "root"
  # root 'welcome#index'

  # Example of regular route:
  #   get 'products/:id' => 'catalog#view'

  # Example of named route that can be invoked with purchase_url(id: product.id)
  #   get 'products/:id/purchase' => 'catalog#purchase', as: :purchase

  # Example resource route (maps HTTP verbs to controller actions automatically):
  #   resources :products

  # Example resource route with options:
  #   resources :products do
  #     member do
  #       get 'short'
  #       post 'toggle'
  #     end
  #
  #     collection do
  #       get 'sold'
  #     end
  #   end

  # Example resource route with sub-resources:
  #   resources :products do
  #     resources :comments, :sales
  #     resource :seller
  #   end

  # Example resource route with more complex sub-resources:
  #   resources :products do
  #     resources :comments
  #     resources :sales do
  #       get 'recent', on: :collection
  #     end
  #   end

  # Example resource route with concerns:
  #   concern :toggleable do
  #     post 'toggle'
  #   end
  #   resources :posts, concerns: :toggleable
  #   resources :photos, concerns: :toggleable

  # Example resource route within a namespace:
  #   namespace :admin do
  #     # Directs /admin/products/* to Admin::ProductsController
  #     # (app/controllers/admin/products_controller.rb)
  #     resources :products
  #   end
end
