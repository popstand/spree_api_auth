Spree::Core::Engine.add_routes do
  namespace :api, defaults: {format: 'json'} do
    namespace :v1 do
      resource :users do
        post :sign_up
        post :sign_in
        post :update_preferences
        post :email_availability_check
        get :get_user
        get :favorite_products
        get :followed_brands
        get :followed_brands_products
      end

      # Following and unfollowing brands.
      post 'taxons/:id/follow', to: 'taxons#follow'
      post 'taxons/:id/unfollow', to: 'taxons#unfollow'

      # Adding and removing favorite products.
      post 'products/:id/add_favorite', to: 'products#add_favorite'
      post 'products/:id/remove_favorite', to: 'products#remove_favorite'

      # Trending products, includes:
      #  - Hitting / pinging a product
      #  - Returning trending products
      get 'products/:id/punch', to: 'products#punch'
      get 'products/trending', to: 'products#trending'
    end
  end
end
