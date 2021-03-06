module Spree
  module Api
    module V1

      TaxonsController.class_eval do
        before_action :authenticate_user, :except => [:unauthorized_taxons]

        # Allow for users to follow brands. Since
        # brands  are represented  by taxons,  we
        # join users to taxons.
        def follow
          taxon = Spree::Taxon.find(params[:id])

          # Handle uniqueness exception if
          # association already exists.
          begin
            taxon.users << current_api_user
            render "spree/api/v1/shared/success", status: 200
          rescue ActiveRecord::RecordNotUnique
            render "spree/api/v1/taxons/already_following", status: 400
          end
        end

        # Allow for users to remove themselves
        # from  following a particular  brand.
        def unfollow
          taxon = Spree::Taxon.find(params[:id])
          taxon.users.delete(current_api_user)
          render "spree/api/v1/shared/success", status: 200
        end

        def index
          if taxonomy
            @taxons = taxonomy.root.children.order(position: :desc)
          else
            if params[:ids]
              @taxons = Spree::Taxon.includes(:children).accessible_by(current_ability, :read).where(id: params[:ids].split(',')).order(position: :desc)
            else
              @taxons = Spree::Taxon.includes(:children).accessible_by(current_ability, :read).order(position: :desc).ransack(params[:q]).result
            end
          end

          @current_api_user = current_api_user
          @taxons = @taxons.page(params[:page]).per(params[:per_page])
          respond_with(@taxons)
        end

        def unauthorized_taxons
          if params[:id]
            @taxons = Spree::Taxonomy.find(params[:id]).root.children.order(position: :desc)
          end

          @current_api_user = nil
          @taxons = @taxons.page(params[:page]).per(params[:per_page])
          respond_with(@taxons)
        end

        def follwed_brands_search
          if (@taxons = Spree::Taxon.find(18).children.where("name ILIKE ?", "%#{params[:q]}%")).present?
            @current_api_user = current_api_user
            @taxons = @taxons.page(params[:page]).per(params[:per_page])
            respond_with(@taxons)
          else
            render "spree/api/v1/taxons/no_followed_brands_search_results", :status => 400 and return
          end
        end
      end
    end
  end
end
