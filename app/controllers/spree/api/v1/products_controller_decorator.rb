module Spree
  module Api
    module V1

      ProductsController.class_eval do
        before_action :authenticate_user, :except => [:unauthorized_products, :unauthorized_product_show, :trending]

        # /api/v1/products/unauthorized/?per_page=12&page=1
        def unauthorized_products
          if params.has_key?(:q)
            brand_retailer_product_ids = []
            related_product_ids = Spree::Product.all.in_name_or_description(params[:q]).pluck(:id)

            if (brands_retailers = Spree::Taxon.where("name ILIKE ?", "%#{params[:q]}%")).present?
              brands_retailers.each do |br|
                brand_retailer_product_ids.concat(br.products.pluck(:id))
              end
            end

            brand_retailer_product_ids = brand_retailer_product_ids.concat(related_product_ids)

            if brand_retailer_product_ids.blank?
              @products = Spree::Product.all.order(created_at: :desc).uniq
            else
              @products = Spree::Product.where(id: brand_retailer_product_ids.uniq)
            end
          else
            @products = Spree::Product.all.order(created_at: :desc).uniq unless params.has_key?(:in_taxons)
          end

          if params.has_key?(:in_taxons)
            taxon_ids = params[:in_taxons].split(',').map(&:to_i)
            @products = params.has_key?(:q) ? @products.in_taxons(taxon_ids) : Spree::Product.all.in_taxons(taxon_ids).order(created_at: :desc).uniq
          end

          if @products.present?
            @products = @products.order(created_at: :desc).uniq
            # Filter products by gender
            if params.has_key?(:gender)
              # 7 is the Male parent taxon
              @products = @products.in_taxons(7) if params[:gender] == "male"

              # 8 is the Female parent taxon
              @products = @products.in_taxons(8) if params[:gender] == "female"
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

          # Only show available (not discontinued) products
          @products = @products.available

          # Pagination
          @products = @products.page(params[:page]).per(params[:per_page])
          @current_api_user = nil

          # Set cache invalidation
          expires_in 15.minutes, :public => true
          headers['Surrogate-Control'] = "max-age=#{15.minutes}"

          # Respond with the products
          respond_with(@products)
        end

        # /api/v1/products/:id/unauthorized
        def unauthorized_product_show
          @current_api_user = nil
          @product = Spree::Product.find(params[:id])
          expires_in 15.minutes, :public => true
          headers['Surrogate-Control'] = "max-age=#{15.minutes}"
          headers['Surrogate-Key'] = "product_id=1"
          respond_with(@product)
        end

        def index
          # this is the start of the collection of products to send the user
          # first we prioritize the search :q param against all products
          # then if no search query
          # we build a collection based on the users set prefernces
          # if user has no preferences set we grab all products
          if params.has_key?(:in_taxons) or params.has_key?(:q)
            if params.has_key?(:q)
              brand_retailer_product_ids = []
              related_product_ids = Spree::Product.all.in_name_or_description(params[:q]).pluck(:id)

              if (brands_retailers = Spree::Taxon.where("name ILIKE ?", "%#{params[:q]}%")).present?
                brands_retailers.each do |br|
                  brand_retailer_product_ids.concat(br.products.pluck(:id))
                end
              end

              brand_retailer_product_ids = brand_retailer_product_ids.concat(related_product_ids)

              brand_retailer_product_ids.blank? ? @products = Spree::Product.all.order(created_at: :desc).uniq : @products = Spree::Product.where(id: brand_retailer_product_ids.uniq)
            end

            if params.has_key?(:in_taxons)
              taxon_ids = params[:in_taxons].split(',').map(&:to_i)
              @products = params.has_key?(:q) ? @products.in_taxons(taxon_ids) : Spree::Product.all.in_taxons(taxon_ids).order(created_at: :desc).uniq
            end
          else
            if params.has_key?(:gender) or params.has_key?(:price_floor) or params.has_key?(:price_ceiling) or params.has_key?(:option_type) or params.has_key?(:option_value)
              @products = Spree::Product.all.order(created_at: :desc).uniq
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
                case current_api_user.gender
                when "Female"
                  @products = Spree::Product.in_taxons(8).uniq
                when "Male"
                  @products = Spree::Product.in_taxons(7).uniq
                else
                  @products = Spree::Product.all.uniq
                end
              end
            end
          end

          if @products.present?
            @products = @products.order(created_at: :desc).uniq
            # Filter products by gender
            if params.has_key?(:gender)
              # 7 is the Male parent taxon
              @products = @products.in_taxons(7) if params[:gender] == "male"

              # 8 is the Female parent taxon
              @products = @products.in_taxons(8) if params[:gender] == "female"
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

          # Don't show discontinued products
          @products = @products.available

          # Pagination
          @products = @products.page(params[:page]).per(params[:per_page])
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
          if current_api_user
            case current_api_user.gender
            when "Female"
              products = Spree::Product.most_hit(1.month.ago, nil).in_taxons(8).pluck(:id)
              @products = Spree::Product.where(id: products.uniq)
            when "Male"
              products = Spree::Product.most_hit(1.month.ago, nil).in_taxons(7).pluck(:id)
              @products = Spree::Product.where(id: products.uniq)
            else
              @products = Spree::Product.most_hit(1.month.ago, nil)
            end
          else
            @products = Spree::Product.most_hit(1.month.ago, nil)
          end

          @products = @products.order(created_at: :desc)
          @products = @products.page(params[:page]).per(params[:per_page])

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
