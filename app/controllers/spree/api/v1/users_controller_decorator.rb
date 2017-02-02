module Spree
  module Api
    module V1

      UsersController.class_eval do
        before_action :authenticate_user, :except => [:sign_up, :sign_in, :email_availability_check]

        def update_preferences
          @user = Spree::User.where(spree_api_key: request.headers['X-Spree-Token']).first

          if @user.update(preferences: YAML.load(params[:user][:preferences].to_json))
            respond_with(@user, :status => 200, :default_template => :show)
          else
            invalid_resource!(user)
          end
        end

        def sign_up
          @user = Spree::User.find_by_email(params[:user][:email])

          if @user.present?
            render "spree/api/v1/users/user_exists", :status => 400 and return
          end

          @user = Spree::User.new(user_params)
          if !@user.save
            #unauthorized
            #return
            render "spree/api/v1/users/unable_to_sign_up", :status => 400 and return
          end
          @user.generate_spree_api_key!
        end

        def sign_in
          @user = Spree::User.find_by_email(params[:user][:email])
          if !@user.present? || !@user.valid_password?(params[:user][:password])
            #unauthorized
            #return
            render "spree/api/v1/users/unable_to_sign_in", :status => 400 and return
          end
          @user.generate_spree_api_key! if @user.spree_api_key.blank?
        end

        def email_availability_check
          @user = Spree::User.find_by_email(params[:user][:email])

          unless params[:user].has_key?(:email)
            render inline: "", :status => 400 and return
          end

          if @user.present?
            render "spree/api/v1/users/email_unavailable", :status => 400 and return
          else
            render "spree/api/v1/users/email_available", :status => 200 and return
          end
        end

        def get_user
          @user = Spree::User.where(spree_api_key: request.headers['X-Spree-Token'])
        end

        def followed_brands
          # Get the brands (taxons) that a user followers
          @taxons = current_api_user.followed_brands
          @taxons.page(params[:page]).per(params[:per_page])
          render "spree/api/v1/users/followed_brands", :status => 200 and return
        end

        def favorite_products
          @products = current_api_user.favorite_products.all
          @products = @products.distinct.page(params[:page]).per(params[:per_page])
          expires_in 15.minutes, :public => true
          headers['Surrogate-Control'] = "max-age=#{15.minutes}"

          render "spree/api/v1/products/index", :status => 200 and return
        end

        def followed_brands_products
          case current_api_user.gender
          when "Female"
            @products = Spree::Product.all_from_brands_followed_by(current_api_user).in_taxons(8)
          when "Male"
            @products = Spree::Product.all_from_brands_followed_by(current_api_user).in_taxons(7)
          else
            @products = Spree::Product.all_from_brands_followed_by(current_api_user)
          end

          @products = @products.order(created_at: :desc)

          if @products.any?
            @products = @products.distinct.page(params[:page]).per(params[:per_page])
            expires_in 15.minutes, :public => true
            headers['Surrogate-Control'] = "max-age=#{15.minutes}"

            render "spree/api/v1/products/index", :status => 200 and return
          else
            render "spree/api/v1/products/not_following_any_brands", :status => 400 and return
          end
        end

        def user_params
          params.require(:user).permit(:email, :password, :password_confirmation,
                                       :preferences, :full_name, :gender, :birthdate, :notify_in)
        end
      end
    end
  end
end
