module Spree
  module Api
    module V1

      ProductsController.class_eval do

        def index
          # this is the start of the collection of products to send the user
          # first we prioritize the search :q param against all products
          # then if no search query
          # we build a collection based on the users set prefernces
          # if user has no preferences set we grab all products

          if params.has_key?(:q)
            @products = Spree::Product.all
          elsif params.has_key?(:in_taxons)
            taxon_ids = params[:in_taxons].split(',').map(&:to_i)
            @products = params.has_key?(:q) ? @products.in_taxons(taxon_ids) : Spree::Product.all.in_taxons(taxon_ids)
          else
            if (selected_sizes = current_api_user.preferences["selected_sizes"]).present?
              product_ids = []
              selected_sizes.keys.each do |taxon|
                selected_sizes[taxon].keys.each do |option_type|
                  selected_sizes[taxon][option_type].each do |option_value|
                    product_ids.concat(Spree::Product.with_option_value(option_type, option_value).in_taxons(taxon.to_i).pluck(:id))
                  end
                end
              end
              @products = Spree::Product.where(id: product_ids.uniq)
            else
              @products = Spree::Product.all
            end
          end

          if @products.present?
            # Order products from newest to oldest
            @products = @products.order("created_at DESC")

            # Filter products by gender
            if params.has_key?(:gender)
              if params[:gender] == "male"
                # 7 is the Male parent taxon
                @products = @products.in_taxons(7)
              else
                # 8 is the Female parent taxon
                @products = @products.in_taxons(8)
              end
            end

            # Filter products by name or description
            if params.has_key?(:q)
              @products = @products.in_name_or_description(params[:q])
            end


            # Filter products  by  price. Both  parameters
            #  ('price_floor', 'price_ceiling are required
            #  for the filter to trigger
            if params.has_key?(:price_floor) and params.has_key?(:price_ceiling)
              @products = @products.price_between(params[:price_floor], params[:price_ceiling])
            end

            # Filter products by their option types (i.e., 'mens-basic-sizes')
            #  and  option  values (i.e.,  Small,  Medium,  Large, etc.). Both
            #  parameters are required for it to work.
            if params.has_key?(:option_type) and params.has_key?(:option_value)
              @products = @products.with_option_value(params[:option_type], params[:option_value])
            end
          end

          # Pagination
          @products = @products.distinct.page(params[:page]).per(params[:per_page])
          @current_api_user = current_api_user

          # Set cache invalidation
          expires_in 15.minutes, :public => true
          headers['Surrogate-Control'] = "max-age=#{15.minutes}"

          # Respond with the products
          respond_with(@products)
        end

        def show
          @current_api_user = current_api_user
          @product = find_product(params[:id])
          expires_in 15.minutes, :public => true
          headers['Surrogate-Control'] = "max-age=#{15.minutes}"
          headers['Surrogate-Key'] = "product_id=1"
          respond_with(@product)
        end

        # Allows users to add to their list of favorite products
        def add_favorite
          product = Spree::Product.find(params[:id])

          # Handle uniqueness exception if association already exists.
          begin
            product.users_who_favorited << current_api_user
            render "spree/api/v1/shared/success", status: 200
          rescue ActiveRecord::RecordNotUnique
            render "spree/api/v1/taxons/already_favorited", status: 400
          end
        end

        # Allows users to remove from their list of favorite products.
        def remove_favorite
          product = Spree::Product.find(params[:id])

          if product.favorited_by?(current_api_user)
            product.users_who_favorited.delete(current_api_user)
            render "spree/api/v1/shared/success", status: 200
          else
            render "spree/api/v1/products/not_favorited", status: 400
          end
        end

        def trending
          @products = Spree::Product.most_hit(1.month.ago, 20).all

          expires_in 15.minutes, :public => true
          headers['Surrogate-Control'] = "max-age=#{15.minutes}"

          render "spree/api/v1/products/trending", :status => 200 and return
        end

        def punch
          product = Spree::Product.find(params[:id])
          product.punch(request)
          render "spree/api/v1/shared/success", status: 200
        end

      end
    end
  end
end
